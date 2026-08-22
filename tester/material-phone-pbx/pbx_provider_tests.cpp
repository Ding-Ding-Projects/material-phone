#include "material_phone/pbx/pbx_provider.hpp"

#include <chrono>
#include <functional>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace pbx = material_phone::pbx;

namespace {

void require(const bool condition, const std::string &message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

pbx::SessionOptions session_options(pbx::ProtocolVersion maximum = {1, 0}) {
    return {"simulator://local", "vault://test-credential", {1, 0}, maximum};
}

std::unique_ptr<pbx::PbxSession> open(const pbx::SimulatorState state,
                                      pbx::ProtocolVersion maximum = {1, 0}) {
    pbx::SimulatorPbxProviderFactory factory({state});
    auto provider = factory.create();
    auto opened = provider->open_session(session_options(maximum), {});
    require(opened.has_value(), "expected simulator session to open");
    return std::move(opened.value());
}

pbx::PbxCommand update_command(const std::string &key,
                               const std::uint64_t expected_revision = 7) {
    return {pbx::CommandKind::UpdateResource,
            "ext-100",
            key,
            expected_revision,
            {{"state", "away"}}};
}

pbx::PbxCommand control_command(const pbx::CommandKind kind,
                                std::string target,
                                std::string key,
                                const std::uint64_t expected_revision) {
    return {kind, std::move(target), std::move(key), expected_revision, {}};
}

void healthy_capabilities() {
    auto session = open(pbx::SimulatorState::Healthy);
    require(session->capabilities().has(pbx::Capability::ReadResources),
            "healthy session must read resources");
    require(session->capabilities().has(pbx::Capability::WriteResources),
            "healthy session must write resources");
    auto resource = session->get_resource("ext-100", {});
    require(resource && resource.value().revision == 7, "seeded resource revision must be stable");
}

void pagination() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto first = session->list_resources(pbx::ResourceKind::Extension, {1, std::nullopt}, {});
    require(first && first.value().items.size() == 1 && first.value().next_cursor,
            "first page must contain a cursor");
    auto second = session->list_resources(
        pbx::ResourceKind::Extension, {1, first.value().next_cursor}, {});
    require(second && second.value().items.size() == 1 && !second.value().next_cursor,
            "second page must exhaust the deterministic collection");
    require(first.value().items.front().id != second.value().items.front().id,
            "pages must not overlap");
}

void bounded_validation() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto zero = session->list_resources(pbx::ResourceKind::Extension, {0, std::nullopt}, {});
    require(!zero && zero.error().code == pbx::ErrorCode::InvalidArgument,
            "zero-sized pages must be rejected");
    auto huge = session->list_resources(
        pbx::ResourceKind::Extension, {pbx::kMaxPageSize + 1, std::nullopt}, {});
    require(!huge && huge.error().code == pbx::ErrorCode::InvalidArgument,
            "oversized pages must be rejected");
    auto bad_cursor = session->list_resources(
        pbx::ResourceKind::Extension, {1, std::string{"not-a-cursor"}}, {});
    require(!bad_cursor && bad_cursor.error().code == pbx::ErrorCode::InvalidArgument,
            "opaque cursor syntax must be validated");
}

void exact_attribute_ceiling() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto first = update_command("attribute-bound-1");
    first.arguments.clear();
    for (std::size_t index = 0; index < pbx::kMaxCommandArguments; ++index) {
        first.arguments.emplace("first-" + std::to_string(index), "value");
    }
    auto applied = session->execute(first, {});
    require(applied.has_value(), "first bounded attribute batch must apply");

    auto second = update_command("attribute-bound-2", applied.value().resource_revision);
    second.arguments.clear();
    for (std::size_t index = 0; index < pbx::kMaxCommandArguments - 2; ++index) {
        second.arguments.emplace("second-" + std::to_string(index), "value");
    }
    auto filled = session->execute(second, {});
    require(filled.has_value(), "command must be able to fill the exact 64-attribute ceiling");

    auto replace = update_command("attribute-bound-replace", filled.value().resource_revision);
    replace.arguments = {{"state", "busy"}};
    auto replaced = session->execute(replace, {});
    require(replaced.has_value(), "replacing an attribute at the ceiling must remain valid");

    auto overflow = update_command("attribute-bound-overflow",
                                   replaced.value().resource_revision);
    overflow.arguments = {{"sixty-fifth", "nope"}};
    auto rejected = session->execute(overflow, {});
    require(!rejected && rejected.error().code == pbx::ErrorCode::ResourceExhausted,
            "the sixty-fifth attribute must be rejected");
}

void embedded_nul_id() {
    auto session = open(pbx::SimulatorState::Healthy);
    const std::string id{"ext-100\0suffix", 14};
    auto result = session->get_resource(id, {});
    require(!result && result.error().code == pbx::ErrorCode::InvalidArgument,
            "embedded NUL resource identifiers must fail validation");
}

void invalid_resource_kinds() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto pause_extension = session->execute(
        control_command(pbx::CommandKind::PauseQueue, "ext-100", "bad-pause", 7), {});
    require(!pause_extension && pause_extension.error().code == pbx::ErrorCode::InvalidArgument,
            "queue commands must reject extension targets");
    require(pause_extension.error().details.at("required_kind") == "queue",
            "queue mismatch must name the required resource kind");
    auto resume_call = session->execute(
        control_command(pbx::CommandKind::ResumeQueue, "call-demo", "bad-resume", 2), {});
    require(!resume_call && resume_call.error().code == pbx::ErrorCode::InvalidArgument,
            "resume-queue must reject call targets");

    auto start_queue = session->execute(
        control_command(pbx::CommandKind::StartCall, "queue-main", "bad-call", 11), {});
    require(!start_queue && start_queue.error().code == pbx::ErrorCode::InvalidArgument,
            "call commands must reject queue targets");
    require(start_queue.error().details.at("required_kind") == "call",
            "call mismatch must name the required resource kind");
    auto end_extension = session->execute(
        control_command(pbx::CommandKind::EndCall, "ext-100", "bad-end", 7), {});
    require(!end_extension && end_extension.error().code == pbx::ErrorCode::InvalidArgument,
            "end-call must reject extension targets");
}

void call_state_commands() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto ringing = session->get_resource("call-demo", {});
    require(ringing && ringing.value().attributes.at("state") == "ringing",
            "seeded call must begin in ringing state");
    auto started = session->execute(
        control_command(pbx::CommandKind::StartCall, "call-demo", "start-call", 2), {});
    require(started && started.value().resource_revision == 3,
            "start-call must increment the call revision");
    auto connected = session->get_resource("call-demo", {});
    require(connected && connected.value().attributes.at("state") == "connected",
            "start-call must set connected state");

    auto ended = session->execute(
        control_command(pbx::CommandKind::EndCall, "call-demo", "end-call", 3), {});
    require(ended && ended.value().resource_revision == 4,
            "end-call must increment the call revision");
    auto finished = session->get_resource("call-demo", {});
    require(finished && finished.value().attributes.at("state") == "ended",
            "end-call must set ended state");

    auto events = session->read_events({4, 10}, {});
    require(events && events.value().items.size() == 2,
            "call commands must emit two events");
    require(events.value().items[0].kind == pbx::EventKind::CallStateChanged &&
                events.value().items[0].payload.at("state") == "connected" &&
                events.value().items[1].kind == pbx::EventKind::CallStateChanged &&
                events.value().items[1].payload.at("state") == "ended",
            "call events must carry their command-specific state transitions");
}

void queue_state_commands() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto paused = session->execute(
        control_command(pbx::CommandKind::PauseQueue, "queue-main", "pause", 11), {});
    require(paused && paused.value().resource_revision == 12,
            "pause-queue must increment the queue revision");
    auto paused_queue = session->get_resource("queue-main", {});
    require(paused_queue && paused_queue.value().attributes.at("paused") == "true",
            "pause-queue must persist paused state");

    auto resumed = session->execute(
        control_command(pbx::CommandKind::ResumeQueue, "queue-main", "resume", 12), {});
    require(resumed && resumed.value().resource_revision == 13,
            "resume-queue must increment the queue revision");
    auto resumed_queue = session->get_resource("queue-main", {});
    require(resumed_queue && resumed_queue.value().attributes.at("paused") == "false",
            "resume-queue must persist resumed state");

    auto events = session->read_events({4, 10}, {});
    require(events && events.value().items.size() == 2,
            "queue commands must emit two events");
    require(events.value().items[0].kind == pbx::EventKind::Updated &&
                events.value().items[0].payload.at("paused") == "true" &&
                events.value().items[1].kind == pbx::EventKind::Updated &&
                events.value().items[1].payload.at("paused") == "false",
            "queue events must carry their command-specific state transitions");
}

void retention_timestamp_gap() {
    auto session = open(pbx::SimulatorState::Healthy);
    for (std::uint64_t index = 0; index < 4093; ++index) {
        pbx::PbxCommand command{pbx::CommandKind::UpdateResource,
                                "ext-100",
                                "retention-" + std::to_string(index),
                                std::nullopt,
                                {{"state", index % 2 == 0 ? "available" : "away"}}};
        auto result = session->execute(command, {});
        require(result.has_value(), "retention setup command must apply");
    }

    auto gap = session->read_events({0, 1}, {});
    require(!gap && gap.error().code == pbx::ErrorCode::EventGap,
            "event retention must report the evicted prefix as a gap");
    require(gap.error().details.at("first_available_sequence") == "2",
            "retention gap must identify the first retained sequence");

    auto tail = session->read_events({4095, 10}, {});
    require(tail && tail.value().items.size() == 2,
            "retention tail must include sequences 4096 and 4097");
    const auto epoch = std::chrono::system_clock::time_point{std::chrono::seconds{1'700'000'000}};
    for (const auto &event : tail.value().items) {
        const auto elapsed =
            std::chrono::duration_cast<std::chrono::seconds>(event.occurred_at - epoch).count();
        require(elapsed == static_cast<long long>(event.sequence - 1),
                "event timestamps must derive from monotonic sequence, not retained size");
    }
    require(tail.value().items[0].occurred_at < tail.value().items[1].occurred_at,
            "retained event timestamps must remain strictly monotonic");
}

void cancellation() {
    auto session = open(pbx::SimulatorState::Healthy);
    pbx::RequestContext context;
    context.cancellation.cancel();
    auto result = session->get_resource("ext-100", context);
    require(!result && result.error().code == pbx::ErrorCode::Cancelled,
            "cancelled work must not reach the provider operation");
}

void deadline() {
    auto session = open(pbx::SimulatorState::Healthy);
    pbx::RequestContext context;
    context.deadline = std::chrono::steady_clock::now() - std::chrono::milliseconds{1};
    auto result = session->get_resource("ext-100", context);
    require(!result && result.error().code == pbx::ErrorCode::DeadlineExceeded,
            "expired deadlines must fail before work starts");
}

void offline() {
    pbx::SimulatorPbxProviderFactory factory({pbx::SimulatorState::Offline});
    auto result = factory.create()->open_session(session_options(), {});
    require(!result && result.error().code == pbx::ErrorCode::Offline && result.error().retryable,
            "offline state must be explicit and retryable");
}

void unauthorized() {
    pbx::SimulatorPbxProviderFactory factory({pbx::SimulatorState::Unauthorized});
    auto result = factory.create()->open_session(session_options(), {});
    require(!result && result.error().code == pbx::ErrorCode::Unauthorized,
            "unauthorized state must not expose a session");
}

void partial_permission() {
    auto session = open(pbx::SimulatorState::PartialPermission);
    require(session->capabilities().has(pbx::Capability::ReadResources),
            "partial permission must retain reads");
    require(!session->capabilities().has(pbx::Capability::WriteResources),
            "partial permission must advertise missing writes");
    auto result = session->execute(update_command("partial"), {});
    require(!result && result.error().code == pbx::ErrorCode::PermissionDenied,
            "missing capability must be enforced");
}

void rate_limited() {
    auto session = open(pbx::SimulatorState::RateLimited);
    auto result = session->get_resource("ext-100", {});
    require(!result && result.error().code == pbx::ErrorCode::RateLimited &&
                result.error().retryable && result.error().retry_after,
            "rate limit must include bounded retry guidance");
}

void event_gap() {
    auto session = open(pbx::SimulatorState::EventGap);
    auto result = session->read_events({0, 10}, {});
    require(!result && result.error().code == pbx::ErrorCode::EventGap,
            "event gaps must be observable rather than silently skipped");
    require(result.error().details.at("first_available_sequence") == "4",
            "event gap must identify the recovery sequence");
}

void injected_conflict() {
    auto session = open(pbx::SimulatorState::Conflict);
    auto result = session->execute(update_command("injected"), {});
    require(!result && result.error().code == pbx::ErrorCode::Conflict,
            "conflict scenario must reject matching revisions deterministically");
}

void revision_conflict() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto result = session->execute(update_command("stale", 6), {});
    require(!result && result.error().code == pbx::ErrorCode::Conflict,
            "stale revisions must be rejected");
    require(result.error().details.at("actual") == "7",
            "revision conflict must report current revision");
}

void idempotent_replay() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto first = session->execute(update_command("repeat"), {});
    auto second = session->execute(update_command("repeat"), {});
    require(first && second, "both idempotent calls must produce receipts");
    require(first.value().command_id == second.value().command_id,
            "idempotent replay must preserve the original command id");
    require(second.value().status == pbx::CommandStatus::Replayed,
            "idempotent replay must be labelled as a replay");
    require(second.value().resource_revision == 8,
            "idempotent replay must not increment revision twice");
}

void idempotency_collision() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto first = session->execute(update_command("collision"), {});
    require(first.has_value(), "first idempotent call must apply");
    auto changed = update_command("collision", 8);
    changed.arguments["state"] = "busy";
    auto second = session->execute(changed, {});
    require(!second && second.error().code == pbx::ErrorCode::Conflict,
            "reusing an idempotency key for another payload must conflict");
}

void mixed_version() {
    auto session = open(pbx::SimulatorState::MixedVersion, {2, 0});
    require(session->capabilities().negotiated_version == pbx::ProtocolVersion{2, 0},
            "mixed-version simulator must negotiate the highest common version");
    auto resources = session->list_resources(pbx::ResourceKind::Extension, {10, std::nullopt}, {});
    require(resources && resources.value().items.size() == 2,
            "mixed-version seed must contain two extensions");
    require(resources.value().items[0].schema_version == pbx::ProtocolVersion{1, 0} &&
                resources.value().items[1].schema_version == pbx::ProtocolVersion{2, 0},
            "resource versions must remain explicit per record");
}

void unsupported_version() {
    pbx::SimulatorPbxProviderFactory factory({pbx::SimulatorState::Healthy});
    auto options = session_options({3, 0});
    options.minimum_version = {3, 0};
    auto result = factory.create()->open_session(options, {});
    require(!result && result.error().code == pbx::ErrorCode::UnsupportedVersion,
            "non-overlapping versions must fail negotiation");
}

void event_after_command() {
    auto session = open(pbx::SimulatorState::Healthy);
    auto applied = session->execute(update_command("event"), {});
    require(applied.has_value(), "command must apply before event verification");
    auto events = session->read_events({4, 10}, {});
    require(events && events.value().items.size() == 1,
            "applied command must append exactly one event");
    require(events.value().items.front().payload.at("command_id") ==
                applied.value().command_id,
            "command event must reference its receipt");
}

using Test = std::function<void()>;

const std::map<std::string, Test> tests = {
    {"healthy_capabilities", healthy_capabilities},
    {"pagination", pagination},
    {"bounded_validation", bounded_validation},
    {"exact_attribute_ceiling", exact_attribute_ceiling},
    {"embedded_nul_id", embedded_nul_id},
    {"invalid_resource_kinds", invalid_resource_kinds},
    {"call_state_commands", call_state_commands},
    {"queue_state_commands", queue_state_commands},
    {"retention_timestamp_gap", retention_timestamp_gap},
    {"cancellation", cancellation},
    {"deadline", deadline},
    {"offline", offline},
    {"unauthorized", unauthorized},
    {"partial_permission", partial_permission},
    {"rate_limited", rate_limited},
    {"event_gap", event_gap},
    {"injected_conflict", injected_conflict},
    {"revision_conflict", revision_conflict},
    {"idempotent_replay", idempotent_replay},
    {"idempotency_collision", idempotency_collision},
    {"mixed_version", mixed_version},
    {"unsupported_version", unsupported_version},
    {"event_after_command", event_after_command},
};

} // namespace

int main(const int argc, char **argv) {
    if (argc != 2) {
        std::cerr << "usage: material_phone_pbx_tests <case>|--list|--all\n";
        return 2;
    }
    const std::string selection = argv[1];
    if (selection == "--list") {
        for (const auto &[name, test] : tests) {
            (void)test;
            std::cout << name << '\n';
        }
        return tests.empty() ? 1 : 0;
    }
    if (selection == "--all") {
        std::size_t passed = 0;
        for (const auto &[name, test] : tests) {
            try {
                test();
                ++passed;
                std::cout << "PASS " << name << '\n';
            } catch (const std::exception &exception) {
                std::cerr << "FAIL " << name << ": " << exception.what() << '\n';
            }
        }
        if (passed != tests.size()) {
            std::cerr << "FAIL_ALL " << passed << '/' << tests.size() << '\n';
            return 1;
        }
        std::cout << "PASS_ALL " << passed << '/' << tests.size() << '\n';
        return 0;
    }
    const auto found = tests.find(selection);
    if (found == tests.end()) {
        std::cerr << "unknown test case: " << selection << '\n';
        return 2;
    }
    try {
        found->second();
        std::cout << "PASS " << found->first << '\n';
        return 0;
    } catch (const std::exception &exception) {
        std::cerr << "FAIL " << found->first << ": " << exception.what() << '\n';
        return 1;
    }
}
