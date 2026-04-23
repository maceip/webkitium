#pragma once

#include "core/Result.h"
#include "webnn/WebNnTypes.h"

namespace ng {

class PlatformWebNnProvider;

class BackendSelector {
public:
    explicit BackendSelector(PlatformWebNnProvider&);

    Result<WebNnBackend> selectBackend(WebNnBackend preferred) const;
    WebNnDeviceCapabilities queryCapabilities() const;

private:
    WebNnBackendStatus checkBackendStatus(WebNnBackend) const;

    PlatformWebNnProvider& m_provider;
};

} // namespace ng
