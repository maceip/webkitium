#pragma once

#include "core/Result.h"
#include "webnn/WebNnTypes.h"

#include <vector>

namespace ng {

class PlatformModelStorage;

class ModelStorage {
public:
    explicit ModelStorage(PlatformModelStorage&);

    Result<CachedModel> lookup(const ModelId&) const;
    Result<std::vector<CachedModel>> listCached() const;
    Result<StorageQuota> queryQuota() const;

    Result<CachedModel> store(const ModelId&, const std::string& sourcePath,
                              const std::string& sha256);
    Result<void> remove(const ModelId&);
    Result<void> evictIfNeeded(uint64_t requiredBytes);
    Result<void> touchAccessTime(const ModelId&);

private:
    static constexpr int64_t kEvictionAgeDays = 30;

    PlatformModelStorage& m_storage;
};

} // namespace ng
