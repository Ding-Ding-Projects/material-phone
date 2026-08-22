#include "material_phone/pbx/pbx_provider.hpp"

#include <algorithm>
#include <charconv>
#include <mutex>
#include <sstream>
#include <utility>

namespace material_phone::pbx {
namespace {

constexpr std::size_t kMaxSimulatorEvents = 4096;
constexpr std::size_t kMaxSimulatorIdempotencyRecords = 4096;

PbxError error(const ErrorCode code, std::string message, const bool retryable = false) {
    return {code, std::move(message), retryable, std::nullopt, {}};
}

PbxError rate_limited() {
    PbxError result = error(ErrorCode::RateLimited, "simulator rate limit reached", true);
    result.retry_after = std::chrono::milliseconds{750};
    result.details.emplace("scope", "simulator-session");
    return result;
}

bool valid_identifier(const std::string &value) {
    return !value.empty() && value.size() <= kMaxIdentifierBytes &&
           std::find(value.begin(), value.end(), '\0') == value.end();
}

const char *resource_kind_name(const ResourceKind kind) {
    switch (kind) {
    case ResourceKind::Extension:
        return "extension";
    case ResourceKind::Queue:
        return "queue";
    case ResourceKind::Trunk:
        return "trunk";
    case ResourceKind::Call:
        return "call";
    case ResourceKind::Presence:
        return "presence";
    }
    return "unknown";
}

std::chrono::system_clock::time_point event_time(
    const SimulatorOptions &options, const std::uint64_t sequence) {
    return options.clock_epoch +
           std::chrono::seconds{static_cast<std::chrono::seconds::rep>(sequence - 1)};
}

std::string fingerprint(const PbxCommand &command) {
    std::ostringstream stream;
    stream << static_cast<int>(command.kind) << '\n' << command.target_id << '\n';
    if (command.expected_revision) {
        stream << *command.expected_revision;
    }
    stream << '\n';
    for (const auto &[key, value] : command.arguments) {
        stream << key.size() << ':' << key << value.size() << ':' << value << '\n';
    }
    return stream.str();
}

Result<std::size_t> decode_cursor(const std::optional<std::string> &cursor) {
    if (!cursor) {
        return Result<std::size_t>::success(0);
    }
    std::size_t offset = 0;
    const char *begin = cursor->data();
    const char *end = begin + cursor->size();
    const auto parsed = std::from_chars(begin, end, offset);
    if (parsed.ec != std::errc{} || parsed.ptr != end) {
        return Result<std::size_t>::failure(
            error(ErrorCode::InvalidArgument, "cursor is not a valid simulator cursor"));
    }
    return Result<std::size_t>::success(offset);
}

Capability capability_for(const CommandKind kind) {
    switch (kind) {
    case CommandKind::StartCall:
    case CommandKind::EndCall:
        return Capability::ManageCalls;
    case CommandKind::PauseQueue:
    case CommandKind::ResumeQueue:
        return Capability::ManageQueues;
    case CommandKind::UpdateResource:
        return Capability::WriteResources;
    }
    return Capability::WriteResources;
}

class SimulatorSession final : public PbxSession {
public:
    explicit SimulatorSession(SimulatorOptions options, ProtocolVersion negotiated)
        : options_(std::move(options)) {
        capabilities_.negotiated_version = negotiated;
        capabilities_.supported = {Capability::ReadResources,
                                   Capability::WriteResources,
                                   Capability::ReadEvents,
                                   Capability::ManageCalls,
                                   Capability::ManageQueues,
                                   Capability::ObservePresence};
        capabilities_.limits = {{"max_page_size", std::to_string(kMaxPageSize)},
                                {"max_command_arguments",
                                 std::to_string(kMaxCommandArguments)},
                                {"max_retained_events",
                                 std::to_string(kMaxSimulatorEvents)},
                                {"max_idempotency_records",
                                 std::to_string(kMaxSimulatorIdempotencyRecords)}};
        if (options_.state == SimulatorState::PartialPermission) {
            capabilities_.supported.erase(Capability::WriteResources);
            capabilities_.supported.erase(Capability::ManageCalls);
            capabilities_.supported.erase(Capability::ManageQueues);
        }
        seed();
    }

    const ProviderCapabilities &capabilities() const noexcept override {
        return capabilities_;
    }

    Result<Page<PbxResource>> list_resources(const ResourceKind kind,
                                              const PageRequest &page,
                                              const RequestContext &context) override {
        if (auto checked = preflight(context); !checked) {
            return Result<Page<PbxResource>>::failure(checked.error());
        }
        if (auto valid = validate_page_request(page); !valid) {
            return Result<Page<PbxResource>>::failure(valid.error());
        }
        auto decoded = decode_cursor(page.cursor);
        if (!decoded) {
            return Result<Page<PbxResource>>::failure(decoded.error());
        }

        std::lock_guard<std::mutex> lock(mutex_);
        if (auto checked = preflight(context); !checked) {
            return Result<Page<PbxResource>>::failure(checked.error());
        }
        std::vector<PbxResource> matching;
        for (const auto &resource : resources_) {
            if (resource.kind == kind) {
                matching.push_back(resource);
            }
        }
        if (decoded.value() > matching.size()) {
            return Result<Page<PbxResource>>::failure(
                error(ErrorCode::InvalidArgument, "cursor is beyond the resource collection"));
        }
        Page<PbxResource> result;
        result.snapshot_revision = snapshot_revision_;
        const std::size_t end = std::min(matching.size(), decoded.value() + page.limit);
        result.items.assign(matching.begin() + static_cast<std::ptrdiff_t>(decoded.value()),
                            matching.begin() + static_cast<std::ptrdiff_t>(end));
        if (end < matching.size()) {
            result.next_cursor = std::to_string(end);
        }
        return Result<Page<PbxResource>>::success(std::move(result));
    }

    Result<PbxResource> get_resource(const std::string &id,
                                     const RequestContext &context) override {
        if (auto checked = preflight(context); !checked) {
            return Result<PbxResource>::failure(checked.error());
        }
        if (!valid_identifier(id)) {
            return Result<PbxResource>::failure(
                error(ErrorCode::InvalidArgument,
                      "resource id is empty, oversized, or contains NUL"));
        }
        std::lock_guard<std::mutex> lock(mutex_);
        if (auto checked = preflight(context); !checked) {
            return Result<PbxResource>::failure(checked.error());
        }
        const auto found = find_resource(id);
        if (found == resources_.end()) {
            return Result<PbxResource>::failure(
                error(ErrorCode::NotFound, "resource does not exist"));
        }
        return Result<PbxResource>::success(*found);
    }

    Result<CommandReceipt> execute(const PbxCommand &command,
                                   const RequestContext &context) override {
        if (auto checked = preflight(context); !checked) {
            return Result<CommandReceipt>::failure(checked.error());
        }
        if (auto valid = validate_command(command); !valid) {
            return Result<CommandReceipt>::failure(valid.error());
        }
        if (!capabilities_.has(capability_for(command.kind))) {
            return Result<CommandReceipt>::failure(
                error(ErrorCode::PermissionDenied, "session lacks the command capability"));
        }

        std::lock_guard<std::mutex> lock(mutex_);
        if (auto checked = preflight(context); !checked) {
            return Result<CommandReceipt>::failure(checked.error());
        }
        const std::string command_fingerprint = fingerprint(command);
        const auto replay = receipts_.find(command.idempotency_key);
        if (replay != receipts_.end()) {
            if (replay->second.fingerprint != command_fingerprint) {
                return Result<CommandReceipt>::failure(error(
                    ErrorCode::Conflict,
                    "idempotency key was already used for a different command"));
            }
            CommandReceipt receipt = replay->second.receipt;
            receipt.status = CommandStatus::Replayed;
            return Result<CommandReceipt>::success(std::move(receipt));
        }

        auto found = find_resource(command.target_id);
        if (found == resources_.end()) {
            return Result<CommandReceipt>::failure(
                error(ErrorCode::NotFound, "command target does not exist"));
        }
        const ResourceKind required_kind =
            command.kind == CommandKind::StartCall || command.kind == CommandKind::EndCall
                ? ResourceKind::Call
                : ResourceKind::Queue;
        if (command.kind != CommandKind::UpdateResource && found->kind != required_kind) {
            PbxError incompatible = error(
                ErrorCode::InvalidArgument,
                "command is not compatible with the target resource kind");
            incompatible.details = {{"actual_kind", resource_kind_name(found->kind)},
                                    {"required_kind", resource_kind_name(required_kind)}};
            return Result<CommandReceipt>::failure(std::move(incompatible));
        }
        if (options_.state == SimulatorState::Conflict) {
            return Result<CommandReceipt>::failure(
                error(ErrorCode::Conflict, "simulator injected a revision conflict"));
        }
        if (command.expected_revision && *command.expected_revision != found->revision) {
            PbxError conflict = error(ErrorCode::Conflict, "resource revision does not match");
            conflict.details.emplace("expected", std::to_string(*command.expected_revision));
            conflict.details.emplace("actual", std::to_string(found->revision));
            return Result<CommandReceipt>::failure(std::move(conflict));
        }

        std::map<std::string, std::string> mutations;
        EventKind event_kind = EventKind::Updated;
        switch (command.kind) {
        case CommandKind::UpdateResource:
            mutations = command.arguments;
            break;
        case CommandKind::StartCall:
            if (!command.arguments.empty()) {
                return Result<CommandReceipt>::failure(error(
                    ErrorCode::InvalidArgument,
                    "start-call does not accept provider-neutral arguments"));
            }
            mutations.emplace("state", "connected");
            event_kind = EventKind::CallStateChanged;
            break;
        case CommandKind::EndCall:
            if (!command.arguments.empty()) {
                return Result<CommandReceipt>::failure(error(
                    ErrorCode::InvalidArgument,
                    "end-call does not accept provider-neutral arguments"));
            }
            mutations.emplace("state", "ended");
            event_kind = EventKind::CallStateChanged;
            break;
        case CommandKind::PauseQueue:
            if (!command.arguments.empty()) {
                return Result<CommandReceipt>::failure(error(
                    ErrorCode::InvalidArgument,
                    "pause-queue does not accept provider-neutral arguments"));
            }
            mutations.emplace("paused", "true");
            break;
        case CommandKind::ResumeQueue:
            if (!command.arguments.empty()) {
                return Result<CommandReceipt>::failure(error(
                    ErrorCode::InvalidArgument,
                    "resume-queue does not accept provider-neutral arguments"));
            }
            mutations.emplace("paused", "false");
            break;
        }

        std::size_t resulting_attribute_count = found->attributes.size();
        for (const auto &[key, value] : mutations) {
            (void)value;
            if (found->attributes.find(key) == found->attributes.end()) {
                ++resulting_attribute_count;
            }
        }
        if (resulting_attribute_count > kMaxAttributeEntries) {
            return Result<CommandReceipt>::failure(error(
                ErrorCode::ResourceExhausted,
                "command would exceed the resource attribute bound"));
        }
        if (receipts_.size() >= kMaxSimulatorIdempotencyRecords) {
            return Result<CommandReceipt>::failure(error(
                ErrorCode::ResourceExhausted,
                "simulator idempotency record bound has been reached"));
        }

        for (const auto &[key, value] : mutations) {
            found->attributes[key] = value;
        }
        ++found->revision;
        ++snapshot_revision_;

        CommandReceipt receipt{"sim-command-" + std::to_string(next_command_id_++),
                               CommandStatus::Applied,
                               found->id,
                               found->revision};
        receipts_.emplace(command.idempotency_key,
                          StoredReceipt{command_fingerprint, receipt});
        const std::uint64_t event_sequence = next_event_sequence_++;
        std::map<std::string, std::string> event_payload = mutations;
        event_payload.emplace("command_id", receipt.command_id);
        events_.push_back(PbxEvent{event_sequence,
                                   event_kind,
                                   found->id,
                                   found->revision,
                                   found->schema_version,
                                   event_time(options_, event_sequence),
                                   std::move(event_payload)});
        if (events_.size() > kMaxSimulatorEvents) {
            events_.erase(events_.begin());
        }
        return Result<CommandReceipt>::success(std::move(receipt));
    }

    Result<Page<PbxEvent>> read_events(const EventPageRequest &page,
                                       const RequestContext &context) override {
        if (auto checked = preflight(context); !checked) {
            return Result<Page<PbxEvent>>::failure(checked.error());
        }
        if (auto valid = validate_event_page_request(page); !valid) {
            return Result<Page<PbxEvent>>::failure(valid.error());
        }
        if (!capabilities_.has(Capability::ReadEvents)) {
            return Result<Page<PbxEvent>>::failure(
                error(ErrorCode::PermissionDenied, "session cannot read events"));
        }
        std::lock_guard<std::mutex> lock(mutex_);
        if (auto checked = preflight(context); !checked) {
            return Result<Page<PbxEvent>>::failure(checked.error());
        }
        if (!events_.empty() && page.after_sequence < events_.front().sequence - 1) {
            PbxError gap = error(ErrorCode::EventGap,
                                 "requested event sequence is no longer retained");
            gap.details = {
                {"first_available_sequence", std::to_string(events_.front().sequence)},
                {"requested_after_sequence", std::to_string(page.after_sequence)}};
            return Result<Page<PbxEvent>>::failure(std::move(gap));
        }
        if (options_.state == SimulatorState::EventGap && page.after_sequence < 3) {
            PbxError gap = error(ErrorCode::EventGap, "event history contains a deliberate gap");
            gap.details = {{"first_available_sequence", "4"},
                           {"requested_after_sequence", std::to_string(page.after_sequence)}};
            return Result<Page<PbxEvent>>::failure(std::move(gap));
        }
        Page<PbxEvent> result;
        result.snapshot_revision = snapshot_revision_;
        for (const auto &event : events_) {
            if (event.sequence > page.after_sequence && result.items.size() < page.limit) {
                result.items.push_back(event);
            }
        }
        if (!result.items.empty() && result.items.back().sequence < events_.back().sequence) {
            result.next_cursor = std::to_string(result.items.back().sequence);
        }
        return Result<Page<PbxEvent>>::success(std::move(result));
    }

private:
    struct StoredReceipt {
        std::string fingerprint;
        CommandReceipt receipt;
    };

    Result<Unit> preflight(const RequestContext &context) const {
        if (auto checked = check_request_context(context); !checked) {
            return checked;
        }
        if (options_.state == SimulatorState::RateLimited) {
            return Result<Unit>::failure(rate_limited());
        }
        return Result<Unit>::success({});
    }

    std::vector<PbxResource>::iterator find_resource(const std::string &id) {
        return std::find_if(resources_.begin(), resources_.end(),
                            [&](const PbxResource &resource) { return resource.id == id; });
    }

    void seed() {
        const ProtocolVersion v1{1, 0};
        const ProtocolVersion v2 = options_.state == SimulatorState::MixedVersion
                                       ? ProtocolVersion{2, 0}
                                       : v1;
        resources_ = {
            {"ext-100", ResourceKind::Extension, "Reception", 7, v1,
             {{"number", "100"}, {"state", "available"}}},
            {"ext-101", ResourceKind::Extension, "Support", 3, v2,
             {{"number", "101"}, {"state", "busy"}}},
            {"queue-main", ResourceKind::Queue, "Main queue", 11, v1,
             {{"members", "2"}, {"paused", "false"}}},
            {"call-demo", ResourceKind::Call, "Demonstration call", 2, v2,
             {{"state", "ringing"}}}};
        events_ = {
            {1, EventKind::Created, "ext-100", 1, v1, event_time(options_, 1),
             {{"source", "seed"}}},
            {2, EventKind::Updated, "ext-100", 7, v1,
             event_time(options_, 2), {{"state", "available"}}},
            {3, EventKind::Created, "ext-101", 1, v2,
             event_time(options_, 3), {{"source", "seed"}}},
            {4, EventKind::CallStateChanged, "call-demo", 2, v2,
             event_time(options_, 4), {{"state", "ringing"}}}};
        next_event_sequence_ = 5;
    }

    SimulatorOptions options_;
    ProviderCapabilities capabilities_;
    std::vector<PbxResource> resources_;
    std::vector<PbxEvent> events_;
    std::map<std::string, StoredReceipt> receipts_;
    std::uint64_t snapshot_revision_{1};
    std::uint64_t next_command_id_{1};
    std::uint64_t next_event_sequence_{1};
    mutable std::mutex mutex_;
};

class SimulatorProvider final : public PbxProvider {
public:
    explicit SimulatorProvider(SimulatorOptions options) : options_(std::move(options)) {}

    std::string provider_id() const override { return "material-phone.simulator"; }

    Result<std::unique_ptr<PbxSession>> open_session(
        const SessionOptions &options, const RequestContext &context) override {
        if (auto checked = check_request_context(context); !checked) {
            return Result<std::unique_ptr<PbxSession>>::failure(checked.error());
        }
        if (auto valid = validate_session_options(options); !valid) {
            return Result<std::unique_ptr<PbxSession>>::failure(valid.error());
        }
        if (options_.state == SimulatorState::Offline) {
            return Result<std::unique_ptr<PbxSession>>::failure(
                error(ErrorCode::Offline, "simulator is offline", true));
        }
        if (options_.state == SimulatorState::Unauthorized) {
            return Result<std::unique_ptr<PbxSession>>::failure(
                error(ErrorCode::Unauthorized, "simulator rejected the credential reference"));
        }

        const ProtocolVersion provider_minimum{1, 0};
        const ProtocolVersion provider_maximum = options_.state == SimulatorState::MixedVersion
                                                     ? ProtocolVersion{2, 0}
                                                     : ProtocolVersion{1, 0};
        const ProtocolVersion lower = provider_minimum < options.minimum_version
                                          ? options.minimum_version
                                          : provider_minimum;
        const ProtocolVersion upper = options.maximum_version < provider_maximum
                                          ? options.maximum_version
                                          : provider_maximum;
        if (upper < lower) {
            PbxError mismatch =
                error(ErrorCode::UnsupportedVersion, "no mutually supported protocol version");
            mismatch.details = {{"provider_minimum", "1.0"},
                                {"provider_maximum",
                                 options_.state == SimulatorState::MixedVersion ? "2.0" : "1.0"}};
            return Result<std::unique_ptr<PbxSession>>::failure(std::move(mismatch));
        }
        return Result<std::unique_ptr<PbxSession>>::success(
            std::make_unique<SimulatorSession>(options_, upper));
    }

private:
    SimulatorOptions options_;
};

} // namespace

SimulatorPbxProviderFactory::SimulatorPbxProviderFactory(SimulatorOptions options)
    : options_(std::move(options)) {}

std::unique_ptr<PbxProvider> SimulatorPbxProviderFactory::create() const {
    return std::make_unique<SimulatorProvider>(options_);
}

} // namespace material_phone::pbx
