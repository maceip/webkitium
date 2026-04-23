#pragma once

#include "core/Result.h"
#include "webnn/WebNnTypes.h"
#include "webnn/ModelStorage.h"

namespace ng {

class PlatformModelDownloader;

class ModelDownloader {
public:
    ModelDownloader(PlatformModelDownloader&, ModelStorage&);

    Result<ModelAvailability> checkAvailability(const ModelDescriptor&);

    Result<CachedModel> download(const ModelDescriptor&,
                                  DownloadProgressCallback = nullptr);

    Result<void> cancel(const ModelId&);

    Result<bool> verifyIntegrity(const CachedModel&,
                                  const std::string& expectedSha256) const;

private:
    PlatformModelDownloader& m_downloader;
    ModelStorage& m_storage;
};

} // namespace ng
