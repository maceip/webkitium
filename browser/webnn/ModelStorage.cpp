#include "webnn/ModelStorage.h"
#include "platform/PlatformAdapters.h"

#include <algorithm>
#include <chrono>

namespace ng {

ModelStorage::ModelStorage(PlatformModelStorage& storage)
    : m_storage(storage)
{
}

Result<CachedModel> ModelStorage::lookup(const ModelId& id) const
{
    return m_storage.lookup(id);
}

Result<std::vector<CachedModel>> ModelStorage::listCached() const
{
    return m_storage.listCached();
}

Result<StorageQuota> ModelStorage::queryQuota() const
{
    return m_storage.queryQuota();
}

Result<CachedModel> ModelStorage::store(const ModelId& id,
                                         const std::string& sourcePath,
                                         const std::string& sha256)
{
    auto quota = queryQuota();
    if (!quota)
        return Result<CachedModel>::fail(quota.error());

    return m_storage.store(id, sourcePath, sha256);
}

Result<void> ModelStorage::remove(const ModelId& id)
{
    return m_storage.remove(id);
}

Result<void> ModelStorage::touchAccessTime(const ModelId& id)
{
    return m_storage.touchAccessTime(id);
}

Result<void> ModelStorage::evictIfNeeded(uint64_t requiredBytes)
{
    auto quota = queryQuota();
    if (!quota)
        return Result<void>::fail(quota.error());

    if (quota.value().availableBytes >= requiredBytes)
        return Result<void>::ok();

    auto cached = listCached();
    if (!cached)
        return Result<void>::fail(cached.error());

    auto& models = cached.value();
    std::sort(models.begin(), models.end(),
        [](const CachedModel& a, const CachedModel& b) {
            return a.lastAccessTimestamp < b.lastAccessTimestamp;
        });

    auto now = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();

    uint64_t freed = 0;
    for (auto& model : models) {
        int64_t ageDays = (now - model.lastAccessTimestamp) / 86400;
        if (ageDays < kEvictionAgeDays)
            continue;

        auto removeResult = remove(model.id);
        if (removeResult)
            freed += model.sizeBytes;

        if (quota.value().availableBytes + freed >= requiredBytes)
            return Result<void>::ok();
    }

    if (quota.value().availableBytes + freed < requiredBytes) {
        return Result<void>::fail({ ErrorCode::InternalError,
            "Insufficient storage after eviction" });
    }

    return Result<void>::ok();
}

} // namespace ng
