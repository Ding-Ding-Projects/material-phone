#include "material_phone/pbx/pbx_provider.hpp"

#include <chrono>
#include <functional>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>

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

void cumulative_attribute_bound() {
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
    for (std::size_t index = 0; index < pbx::kMaxCommandArguments; ++index) {
        second.arguments.emplace("second-" + std::to_string(index), "value");
    }
    auto rejected = session->execute(second, {});
    require(!rejected && rejected.error().code == pbx::ErrorCode::ResourceExhausted,
            "cumulative resource attributes must remain bounded");
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
    {"cumulative_attribute_bound", cumulative_attribute_bound},
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
        std::cerr << "usage: material_phone_pbx_tests <case>\n";
        return 2;
    }
    const auto found = tests.find(argv[1]);
    if (found == tests.end()) {
        std::cerr << "unknown test case: " << argv[1] << '\n';
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
