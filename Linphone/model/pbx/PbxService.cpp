#include "PbxService.hpp"

#include <QtConcurrent>

#include <QTimer>
#include <QVariantList>

#include <chrono>
#include <utility>

namespace pbx = material_phone::pbx;

namespace {

constexpr auto kRequestDeadline = std::chrono::seconds{2};

QString errorCodeName(const pbx::ErrorCode code) {
	switch (code) {
		case pbx::ErrorCode::InvalidArgument: return QStringLiteral("invalid_argument");
		case pbx::ErrorCode::Cancelled: return QStringLiteral("cancelled");
		case pbx::ErrorCode::DeadlineExceeded: return QStringLiteral("deadline_exceeded");
		case pbx::ErrorCode::Offline: return QStringLiteral("offline");
		case pbx::ErrorCode::Unauthorized: return QStringLiteral("unauthorized");
		case pbx::ErrorCode::PermissionDenied: return QStringLiteral("permission_denied");
		case pbx::ErrorCode::RateLimited: return QStringLiteral("rate_limited");
		case pbx::ErrorCode::NotFound: return QStringLiteral("not_found");
		case pbx::ErrorCode::Conflict: return QStringLiteral("conflict");
		case pbx::ErrorCode::EventGap: return QStringLiteral("event_gap");
		case pbx::ErrorCode::UnsupportedVersion: return QStringLiteral("unsupported_version");
		case pbx::ErrorCode::ResourceExhausted: return QStringLiteral("resource_exhausted");
		case pbx::ErrorCode::Internal: return QStringLiteral("internal");
	}
	return QStringLiteral("internal");
}

QString capabilityName(const pbx::Capability capability) {
	switch (capability) {
		case pbx::Capability::ReadResources: return QStringLiteral("read_resources");
		case pbx::Capability::WriteResources: return QStringLiteral("write_resources");
		case pbx::Capability::ReadEvents: return QStringLiteral("read_events");
		case pbx::Capability::ManageCalls: return QStringLiteral("manage_calls");
		case pbx::Capability::ManageQueues: return QStringLiteral("manage_queues");
		case pbx::Capability::ObservePresence: return QStringLiteral("observe_presence");
	}
	return QStringLiteral("unknown");
}

QString resourceKindName(const pbx::ResourceKind kind) {
	switch (kind) {
		case pbx::ResourceKind::Extension: return QStringLiteral("extension");
		case pbx::ResourceKind::Queue: return QStringLiteral("queue");
		case pbx::ResourceKind::Trunk: return QStringLiteral("trunk");
		case pbx::ResourceKind::Call: return QStringLiteral("call");
		case pbx::ResourceKind::Presence: return QStringLiteral("presence");
	}
	return QStringLiteral("unknown");
}

QVariantMap resourceToVariant(const pbx::PbxResource &resource) {
	QVariantMap attributes;
	for (const auto &[key, value] : resource.attributes) {
		attributes.insert(QString::fromStdString(key), QString::fromStdString(value));
	}
	return {{QStringLiteral("id"), QString::fromStdString(resource.id)},
	        {QStringLiteral("kind"), resourceKindName(resource.kind)},
	        {QStringLiteral("displayName"), QString::fromStdString(resource.display_name)},
	        {QStringLiteral("revision"), QVariant::fromValue<qulonglong>(resource.revision)},
	        {QStringLiteral("attributes"), attributes}};
}

} // namespace

struct PbxService::WorkerState {
	std::unique_ptr<pbx::PbxProvider> provider;
	std::unique_ptr<pbx::PbxSession> session;
};

PbxService::PbxService(QObject *parent)
    : QObject(parent), mWorkerState(std::make_shared<WorkerState>()) {
	connect(&mRefreshWatcher, &QFutureWatcher<RefreshResult>::finished, this, &PbxService::applyRefreshResult);
	QTimer::singleShot(0, this, &PbxService::refresh);
}

PbxService::~PbxService() {
	cancel();
	if (mRefreshWatcher.isRunning()) mRefreshWatcher.waitForFinished();
}

bool PbxService::providerAvailable() const noexcept {
	return mProviderAvailable;
}

bool PbxService::productionTelephonyAvailable() const noexcept {
	return false;
}

bool PbxService::busy() const noexcept {
	return mBusy;
}

QString PbxService::providerMode() const {
	return QStringLiteral("Local PBX simulator (contract preview only; no production telephony)");
}

QStringList PbxService::capabilities() const {
	return mCapabilities;
}

QVariantMap PbxService::resourcePage() const {
	return mResourcePage;
}

QString PbxService::errorCode() const {
	return mErrorCode;
}

QString PbxService::errorMessage() const {
	return mErrorMessage;
}

void PbxService::refresh() {
	if (mBusy) return;

	mCancellation = pbx::CancellationToken{};
	const auto cancellation = mCancellation;
	const auto workerState = mWorkerState;
	mBusy = true;
	mErrorCode.clear();
	mErrorMessage.clear();
	emit stateChanged();

	auto future = QtConcurrent::run([workerState, cancellation]() -> RefreshResult {
		RefreshResult result;
		const pbx::RequestContext context{
		    cancellation, std::chrono::steady_clock::now() + kRequestDeadline};

		if (!workerState->provider) {
			pbx::SimulatorPbxProviderFactory factory;
			workerState->provider = factory.create();
		}
		if (!workerState->provider) {
			result.errorCode = QStringLiteral("provider_unavailable");
			result.errorMessage = QStringLiteral("The local PBX simulator provider could not be created.");
			return result;
		}

		if (!workerState->session) {
			const pbx::SessionOptions options{QStringLiteral("simulator://local-contract-preview").toStdString(),
			                                  QStringLiteral("local://simulator-no-secret").toStdString(),
			                                  {1, 0},
			                                  {1, 0}};
			auto opened = workerState->provider->open_session(options, context);
			if (!opened) {
				result.errorCode = errorCodeName(opened.error().code);
				result.errorMessage = QString::fromStdString(opened.error().message);
				return result;
			}
			workerState->session = std::move(opened.value());
		}

		result.providerAvailable = true;
		for (const auto capability : workerState->session->capabilities().supported) {
			result.capabilities.append(capabilityName(capability));
		}

		QVariantList items;
		QVariantMap nextCursors;
		QVariantMap snapshotRevisions;
		constexpr pbx::ResourceKind resourceKinds[] = {pbx::ResourceKind::Extension,
		                                               pbx::ResourceKind::Queue,
		                                               pbx::ResourceKind::Trunk,
		                                               pbx::ResourceKind::Call,
		                                               pbx::ResourceKind::Presence};
		for (const auto kind : resourceKinds) {
			auto page = workerState->session->list_resources(kind, pbx::PageRequest{50, std::nullopt}, context);
			if (!page) {
				result.errorCode = errorCodeName(page.error().code);
				result.errorMessage = QString::fromStdString(page.error().message);
				return result;
			}
			for (const auto &resource : page.value().items) items.append(resourceToVariant(resource));
			const auto kindName = resourceKindName(kind);
			if (page.value().next_cursor) {
				nextCursors.insert(kindName, QString::fromStdString(*page.value().next_cursor));
			}
			snapshotRevisions.insert(
			    kindName, QVariant::fromValue<qulonglong>(page.value().snapshot_revision));
		}

		result.resourcePage = {{QStringLiteral("items"), items},
		                       {QStringLiteral("nextCursors"), nextCursors},
		                       {QStringLiteral("snapshotRevisions"), snapshotRevisions},
		                       {QStringLiteral("pageSizePerKind"), 50}};
		return result;
	});
	mRefreshWatcher.setFuture(future);
}

void PbxService::cancel() {
	if (mBusy) mCancellation.cancel();
}

void PbxService::applyRefreshResult() {
	const auto result = mRefreshWatcher.result();
	mProviderAvailable = result.providerAvailable;
	mCapabilities = result.capabilities;
	mResourcePage = result.resourcePage;
	mErrorCode = result.errorCode;
	mErrorMessage = result.errorMessage;
	mBusy = false;
	emit stateChanged();
}
