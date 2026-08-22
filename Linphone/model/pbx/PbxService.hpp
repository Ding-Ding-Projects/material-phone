#pragma once

#include "material_phone/pbx/pbx_provider.hpp"

#include <QFutureWatcher>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

#include <memory>

class PbxService final : public QObject {
	Q_OBJECT

	Q_PROPERTY(bool providerAvailable READ providerAvailable NOTIFY stateChanged)
	Q_PROPERTY(bool productionTelephonyAvailable READ productionTelephonyAvailable CONSTANT)
	Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
	Q_PROPERTY(QString providerMode READ providerMode CONSTANT)
	Q_PROPERTY(QStringList capabilities READ capabilities NOTIFY stateChanged)
	Q_PROPERTY(QVariantMap resourcePage READ resourcePage NOTIFY stateChanged)
	Q_PROPERTY(QString errorCode READ errorCode NOTIFY stateChanged)
	Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)

public:
	explicit PbxService(QObject *parent = nullptr);
	~PbxService() override;

	bool providerAvailable() const noexcept;
	bool productionTelephonyAvailable() const noexcept;
	bool busy() const noexcept;
	QString providerMode() const;
	QStringList capabilities() const;
	QVariantMap resourcePage() const;
	QString errorCode() const;
	QString errorMessage() const;

	Q_INVOKABLE void refresh();
	Q_INVOKABLE void cancel();

signals:
	void stateChanged();

private:
	struct WorkerState;
	struct RefreshResult {
		bool providerAvailable{false};
		QStringList capabilities;
		QVariantMap resourcePage;
		QString errorCode;
		QString errorMessage;
	};

	void applyRefreshResult();

	std::shared_ptr<WorkerState> mWorkerState;
	QFutureWatcher<RefreshResult> mRefreshWatcher;
	material_phone::pbx::CancellationToken mCancellation;
	bool mProviderAvailable{false};
	bool mBusy{false};
	QStringList mCapabilities;
	QVariantMap mResourcePage;
	QString mErrorCode;
	QString mErrorMessage;
};
