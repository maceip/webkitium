#pragma once

#include "core/Origin.h"
#include "core/Result.h"
#include "webnn/WebNnTypes.h"
#include "webnn/BackendSelector.h"
#include "webnn/ModelDownloader.h"
#include "webnn/ModelStorage.h"
#include "webnn/InferenceSession.h"

#include <memory>

namespace ng {

class PlatformWebNnProvider;

struct ModelRegistryEntry {
    ModelDescriptor descriptor;
    ModelAvailability availability { ModelAvailability::Unavailable };
};

class WebNnController {
public:
    WebNnController(PlatformWebNnProvider&, PlatformModelStorage&,
                    PlatformModelDownloader&);

    Result<void> validateAccess(const FrameContext&) const;

    Result<ModelAvailability> checkModelAvailability(const ModelDescriptor&);

    Result<CachedModel> ensureModel(const ModelDescriptor&,
                                     DownloadProgressCallback = nullptr);

    Result<std::unique_ptr<InferenceSession>> createSession(
        const FrameContext&,
        const ModelDescriptor&,
        const SessionConfig&);

    Result<WebNnDeviceCapabilities> queryCapabilities() const;

    const ModelStorage& storage() const { return m_storage; }
    const BackendSelector& backends() const { return m_backendSelector; }

private:
    PlatformWebNnProvider& m_provider;
    ModelStorage m_storage;
    ModelDownloader m_downloader;
    BackendSelector m_backendSelector;
};

} // namespace ng
