#include "webnn/BackendSelector.h"
#include "platform/PlatformAdapters.h"

namespace ng {

BackendSelector::BackendSelector(PlatformWebNnProvider& provider)
    : m_provider(provider)
{
}

WebNnDeviceCapabilities BackendSelector::queryCapabilities() const
{
    return m_provider.queryDeviceCapabilities();
}

WebNnBackendStatus BackendSelector::checkBackendStatus(WebNnBackend backend) const
{
    return m_provider.checkBackendStatus(backend);
}

Result<WebNnBackend> BackendSelector::selectBackend(WebNnBackend preferred) const
{
    auto caps = queryCapabilities();

    if (preferred == WebNnBackend::GPU && caps.hasGpu) {
        auto status = checkBackendStatus(WebNnBackend::GPU);
        if (status == WebNnBackendStatus::Available)
            return Result<WebNnBackend>::ok(WebNnBackend::GPU);
    }

    if (preferred == WebNnBackend::NPU && caps.hasNpu) {
        auto status = checkBackendStatus(WebNnBackend::NPU);
        if (status == WebNnBackendStatus::Available)
            return Result<WebNnBackend>::ok(WebNnBackend::NPU);
    }

    if (caps.hasCpu)
        return Result<WebNnBackend>::ok(WebNnBackend::CPU);

    return Result<WebNnBackend>::fail({ ErrorCode::Unsupported,
        "No suitable ML backend available" });
}

} // namespace ng
