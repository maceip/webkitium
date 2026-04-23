#include "webnn/ModelDownloader.h"
#include "platform/PlatformAdapters.h"

namespace ng {

ModelDownloader::ModelDownloader(PlatformModelDownloader& downloader,
                                 ModelStorage& storage)
    : m_downloader(downloader)
    , m_storage(storage)
{
}

Result<ModelAvailability> ModelDownloader::checkAvailability(
    const ModelDescriptor& descriptor)
{
    auto cached = m_storage.lookup(descriptor.id);
    if (cached)
        return Result<ModelAvailability>::ok(ModelAvailability::Available);

    if (descriptor.url.empty())
        return Result<ModelAvailability>::ok(ModelAvailability::Unavailable);

    return Result<ModelAvailability>::ok(ModelAvailability::Downloadable);
}

Result<CachedModel> ModelDownloader::download(
    const ModelDescriptor& descriptor,
    DownloadProgressCallback progressCallback)
{
    auto cached = m_storage.lookup(descriptor.id);
    if (cached)
        return cached;

    auto evictResult = m_storage.evictIfNeeded(descriptor.sizeBytes);
    if (!evictResult)
        return Result<CachedModel>::fail(evictResult.error());

    auto downloadResult = m_downloader.fetch(
        descriptor.url, descriptor.id, progressCallback);
    if (!downloadResult)
        return Result<CachedModel>::fail(downloadResult.error());

    auto& tempPath = downloadResult.value();

    auto integrityResult = verifyIntegrity(
        CachedModel { descriptor.id, tempPath, descriptor.sizeBytes,
                      descriptor.sha256, 0 },
        descriptor.sha256);

    if (!integrityResult)
        return Result<CachedModel>::fail(integrityResult.error());

    if (!integrityResult.value()) {
        return Result<CachedModel>::fail({ ErrorCode::InternalError,
            "Model integrity check failed — SHA-256 mismatch" });
    }

    return m_storage.store(descriptor.id, tempPath, descriptor.sha256);
}

Result<void> ModelDownloader::cancel(const ModelId& id)
{
    return m_downloader.cancel(id);
}

Result<bool> ModelDownloader::verifyIntegrity(
    const CachedModel& model,
    const std::string& expectedSha256) const
{
    if (expectedSha256.empty())
        return Result<bool>::ok(true);

    auto computedHash = m_downloader.computeSha256(model.localPath);
    if (!computedHash)
        return Result<bool>::fail(computedHash.error());

    return Result<bool>::ok(computedHash.value() == expectedSha256);
}

} // namespace ng
