#include "webnn/WebNnController.h"
#include "platform/PlatformAdapters.h"

namespace ng {

WebNnController::WebNnController(PlatformWebNnProvider& provider,
                                   PlatformModelStorage& storage,
                                   PlatformModelDownloader& downloader)
    : m_provider(provider)
    , m_storage(storage)
    , m_downloader(downloader, m_storage)
    , m_backendSelector(provider)
{
}

Result<void> WebNnController::validateAccess(const FrameContext& frame) const
{
    if (!frame.origin.isPotentiallyTrustworthy())
        return Result<void>::fail({ ErrorCode::PermissionDenied,
            "WebNN requires a secure context" });

    if (!frame.isTopLevel) {
        return Result<void>::fail({ ErrorCode::PermissionDenied,
            "WebNN is not available in cross-origin iframes without "
            "permissions policy" });
    }

    return Result<void>::ok();
}

Result<ModelAvailability> WebNnController::checkModelAvailability(
    const ModelDescriptor& descriptor)
{
    return m_downloader.checkAvailability(descriptor);
}

Result<CachedModel> WebNnController::ensureModel(
    const ModelDescriptor& descriptor,
    DownloadProgressCallback progressCallback)
{
    auto cached = m_storage.lookup(descriptor.id);
    if (cached) {
        m_storage.touchAccessTime(descriptor.id);
        return cached;
    }

    return m_downloader.download(descriptor, std::move(progressCallback));
}

Result<std::unique_ptr<InferenceSession>> WebNnController::createSession(
    const FrameContext& frame,
    const ModelDescriptor& descriptor,
    const SessionConfig& config)
{
    auto accessResult = validateAccess(frame);
    if (!accessResult)
        return Result<std::unique_ptr<InferenceSession>>::fail(
            accessResult.error());

    auto modelResult = ensureModel(descriptor);
    if (!modelResult)
        return Result<std::unique_ptr<InferenceSession>>::fail(
            modelResult.error());

    auto backendResult = m_backendSelector.selectBackend(config.backend);
    if (!backendResult)
        return Result<std::unique_ptr<InferenceSession>>::fail(
            backendResult.error());

    SessionConfig resolvedConfig = config;
    resolvedConfig.backend = backendResult.value();

    return InferenceSession::create(
        m_provider, modelResult.value(), resolvedConfig);
}

Result<WebNnDeviceCapabilities> WebNnController::queryCapabilities() const
{
    return Result<WebNnDeviceCapabilities>::ok(
        m_backendSelector.queryCapabilities());
}

} // namespace ng
