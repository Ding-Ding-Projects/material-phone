#include "material_phone/pbx/pbx_provider.hpp"

#include <algorithm>

namespace material_phone::pbx {
namespace {

PbxError invalid(std::string message) {
    return {ErrorCode::InvalidArgument, std::move(message), false, std::nullopt, {}};
}

bool valid_text(const std::string &value, const std::size_t maximum, const bool allow_empty = false) {
    if ((!allow_empty && value.empty()) || value.size() > maximum) {
        return false;
    }
    return std::find(value.begin(), value.end(), '\0') == value.end();
}

Result<Unit> validate_attributes(const std::map<std::string, std::string> &attributes,
                                 const std::size_t maximum_entries) {
    if (attributes.size() > maximum_entries) {
        return Result<Unit>::failure(invalid("too many attribute entries"));
    }
    for (const auto &[key, value] : attributes) {
        if (!valid_text(key, kMaxIdentifierBytes) ||
            !valid_text(value, kMaxAttributeValueBytes, true)) {
            return Result<Unit>::failure(invalid("attribute key or value exceeds its bound"));
        }
    }
    return Result<Unit>::success({});
}

} // namespace

CancellationToken::CancellationToken()
    : cancelled_(std::make_shared<std::atomic_bool>(false)) {}

void CancellationToken::cancel() const noexcept {
    cancelled_->store(true, std::memory_order_release);
}

bool CancellationToken::is_cancelled() const noexcept {
    return cancelled_->load(std::memory_order_acquire);
}

bool operator==(const ProtocolVersion &left, const ProtocolVersion &right) noexcept {
    return left.major == right.major && left.minor == right.minor;
}

bool operator<(const ProtocolVersion &left, const ProtocolVersion &right) noexcept {
    return left.major < right.major ||
           (left.major == right.major && left.minor < right.minor);
}

bool operator<=(const ProtocolVersion &left, const ProtocolVersion &right) noexcept {
    return left < right || left == right;
}

bool ProviderCapabilities::has(const Capability capability) const noexcept {
    return supported.find(capability) != supported.end();
}

Result<Unit> validate_session_options(const SessionOptions &options) {
    if (!valid_text(options.endpoint, 2048)) {
        return Result<Unit>::failure(invalid("endpoint must be non-empty and at most 2048 bytes"));
    }
    if (!valid_text(options.credential_reference, kMaxIdentifierBytes)) {
        return Result<Unit>::failure(
            invalid("credential reference must be non-empty and bounded"));
    }
    if (options.maximum_version < options.minimum_version) {
        return Result<Unit>::failure(invalid("minimum version exceeds maximum version"));
    }
    return Result<Unit>::success({});
}

Result<Unit> validate_page_request(const PageRequest &page) {
    if (page.limit == 0 || page.limit > kMaxPageSize) {
        return Result<Unit>::failure(invalid("page limit must be between 1 and 200"));
    }
    if (page.cursor && !valid_text(*page.cursor, kMaxIdentifierBytes)) {
        return Result<Unit>::failure(invalid("cursor is empty, oversized, or contains NUL"));
    }
    return Result<Unit>::success({});
}

Result<Unit> validate_event_page_request(const EventPageRequest &page) {
    if (page.limit == 0 || page.limit > kMaxPageSize) {
        return Result<Unit>::failure(invalid("event page limit must be between 1 and 200"));
    }
    return Result<Unit>::success({});
}

Result<Unit> validate_command(const PbxCommand &command) {
    if (!valid_text(command.target_id, kMaxIdentifierBytes)) {
        return Result<Unit>::failure(invalid("command target is empty or oversized"));
    }
    if (!valid_text(command.idempotency_key, kMaxIdentifierBytes)) {
        return Result<Unit>::failure(invalid("idempotency key is empty or oversized"));
    }
    return validate_attributes(command.arguments, kMaxCommandArguments);
}

Result<Unit> check_request_context(const RequestContext &context) {
    if (context.cancellation.is_cancelled()) {
        return Result<Unit>::failure(
            {ErrorCode::Cancelled, "request was cancelled", false, std::nullopt, {}});
    }
    if (context.deadline && std::chrono::steady_clock::now() >= *context.deadline) {
        return Result<Unit>::failure({ErrorCode::DeadlineExceeded,
                                      "request deadline has elapsed",
                                      false,
                                      std::nullopt,
                                      {}});
    }
    return Result<Unit>::success({});
}

} // namespace material_phone::pbx
