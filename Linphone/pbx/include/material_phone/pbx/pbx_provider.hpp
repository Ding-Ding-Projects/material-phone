#pragma once

#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <variant>
#include <vector>

namespace material_phone::pbx {

inline constexpr std::size_t kMaxIdentifierBytes = 128;
inline constexpr std::size_t kMaxLabelBytes = 256;
inline constexpr std::size_t kMaxAttributeEntries = 64;
inline constexpr std::size_t kMaxAttributeValueBytes = 4096;
inline constexpr std::size_t kMaxPageSize = 200;
inline constexpr std::size_t kMaxCommandArguments = 32;

enum class ErrorCode {
    InvalidArgument,
    Cancelled,
    DeadlineExceeded,
    Offline,
    Unauthorized,
    PermissionDenied,
    RateLimited,
    NotFound,
    Conflict,
    EventGap,
    UnsupportedVersion,
    ResourceExhausted,
    Internal
};

struct PbxError {
    ErrorCode code{ErrorCode::Internal};
    std::string message;
    bool retryable{false};
    std::optional<std::chrono::milliseconds> retry_after;
    std::map<std::string, std::string> details;
};

template <typename T>
class Result {
public:
    static Result success(T value) { return Result(std::move(value)); }
    static Result failure(PbxError error) { return Result(std::move(error)); }

    bool has_value() const noexcept { return std::holds_alternative<T>(storage_); }
    explicit operator bool() const noexcept { return has_value(); }
    const T &value() const { return std::get<T>(storage_); }
    T &value() { return std::get<T>(storage_); }
    const PbxError &error() const { return std::get<PbxError>(storage_); }

private:
    explicit Result(T value) : storage_(std::move(value)) {}
    explicit Result(PbxError error) : storage_(std::move(error)) {}
    std::variant<T, PbxError> storage_;
};

struct Unit {};

class CancellationToken {
public:
    CancellationToken();
    void cancel() const noexcept;
    bool is_cancelled() const noexcept;

private:
    std::shared_ptr<std::atomic_bool> cancelled_;
};

struct RequestContext {
    CancellationToken cancellation;
    std::optional<std::chrono::steady_clock::time_point> deadline;
};

struct ProtocolVersion {
    std::uint16_t major{1};
    std::uint16_t minor{0};
};

bool operator==(const ProtocolVersion &left, const ProtocolVersion &right) noexcept;
bool operator<(const ProtocolVersion &left, const ProtocolVersion &right) noexcept;
bool operator<=(const ProtocolVersion &left, const ProtocolVersion &right) noexcept;

enum class Capability {
    ReadResources,
    WriteResources,
    ReadEvents,
    ManageCalls,
    ManageQueues,
    ObservePresence
};

struct ProviderCapabilities {
    ProtocolVersion negotiated_version;
    std::set<Capability> supported;
    std::map<std::string, std::string> limits;

    bool has(Capability capability) const noexcept;
};

enum class ResourceKind { Extension, Queue, Trunk, Call, Presence };

struct PbxResource {
    std::string id;
    ResourceKind kind{ResourceKind::Extension};
    std::string display_name;
    std::uint64_t revision{0};
    ProtocolVersion schema_version{1, 0};
    std::map<std::string, std::string> attributes;
};

struct PageRequest {
    std::size_t limit{50};
    std::optional<std::string> cursor;
};

template <typename T>
struct Page {
    std::vector<T> items;
    std::optional<std::string> next_cursor;
    std::uint64_t snapshot_revision{0};
};

enum class EventKind { Created, Updated, Deleted, CallStateChanged, PresenceChanged };

struct PbxEvent {
    std::uint64_t sequence{0};
    EventKind kind{EventKind::Updated};
    std::string resource_id;
    std::uint64_t resource_revision{0};
    ProtocolVersion schema_version{1, 0};
    std::chrono::system_clock::time_point occurred_at;
    std::map<std::string, std::string> payload;
};

struct EventPageRequest {
    std::uint64_t after_sequence{0};
    std::size_t limit{50};
};

enum class CommandKind { UpdateResource, StartCall, EndCall, PauseQueue, ResumeQueue };

struct PbxCommand {
    CommandKind kind{CommandKind::UpdateResource};
    std::string target_id;
    std::string idempotency_key;
    std::optional<std::uint64_t> expected_revision;
    std::map<std::string, std::string> arguments;
};

enum class CommandStatus { Applied, Replayed };

struct CommandReceipt {
    std::string command_id;
    CommandStatus status{CommandStatus::Applied};
    std::string resource_id;
    std::uint64_t resource_revision{0};
};

struct SessionOptions {
    std::string endpoint;
    std::string credential_reference;
    ProtocolVersion minimum_version{1, 0};
    ProtocolVersion maximum_version{1, 0};
};

class PbxSession {
public:
    virtual ~PbxSession() = default;
    virtual const ProviderCapabilities &capabilities() const noexcept = 0;
    virtual Result<Page<PbxResource>> list_resources(ResourceKind kind,
                                                      const PageRequest &page,
                                                      const RequestContext &context) = 0;
    virtual Result<PbxResource> get_resource(const std::string &id,
                                             const RequestContext &context) = 0;
    virtual Result<CommandReceipt> execute(const PbxCommand &command,
                                           const RequestContext &context) = 0;
    virtual Result<Page<PbxEvent>> read_events(const EventPageRequest &page,
                                               const RequestContext &context) = 0;
};

class PbxProvider {
public:
    virtual ~PbxProvider() = default;
    virtual std::string provider_id() const = 0;
    virtual Result<std::unique_ptr<PbxSession>> open_session(
        const SessionOptions &options, const RequestContext &context) = 0;
};

class PbxProviderFactory {
public:
    virtual ~PbxProviderFactory() = default;
    virtual std::unique_ptr<PbxProvider> create() const = 0;
};

enum class SimulatorState {
    Healthy,
    Offline,
    Unauthorized,
    PartialPermission,
    RateLimited,
    EventGap,
    Conflict,
    MixedVersion
};

struct SimulatorOptions {
    SimulatorState state{SimulatorState::Healthy};
    std::chrono::system_clock::time_point clock_epoch{
        std::chrono::system_clock::time_point{std::chrono::seconds{1'700'000'000}}};
};

class SimulatorPbxProviderFactory final : public PbxProviderFactory {
public:
    explicit SimulatorPbxProviderFactory(SimulatorOptions options = {});
    std::unique_ptr<PbxProvider> create() const override;

private:
    SimulatorOptions options_;
};

Result<Unit> validate_session_options(const SessionOptions &options);
Result<Unit> validate_page_request(const PageRequest &page);
Result<Unit> validate_event_page_request(const EventPageRequest &page);
Result<Unit> validate_command(const PbxCommand &command);
Result<Unit> check_request_context(const RequestContext &context);

} // namespace material_phone::pbx
