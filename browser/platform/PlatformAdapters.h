#pragma once

#include "extensions/ExtensionRuntime.h"
#include "tabs/BrowserStateModel.h"
#include "webauthn/WebAuthnController.h"
#include "webnn/WebNnTypes.h"

#include <string>
#include <vector>

namespace ng {

class PlatformBrowserUI {
public:
    virtual ~PlatformBrowserUI() = default;
    virtual void renderBrowserState(const std::vector<BrowserWindow>&, const std::vector<BrowserTab>&) = 0;
    virtual Result<void> showExtensionPopup(const ExtensionId&, BrowserWindowId, BrowserTabId) = 0;
    virtual Result<void> showExtensionSidePanel(const ExtensionId&, BrowserWindowId) = 0;
};

class PlatformExtensionBridge {
public:
    virtual ~PlatformExtensionBridge() = default;
    virtual Result<void> injectContentScripts(const ExtensionManifest&, const BrowserTab&) = 0;
    virtual Result<void> sendToBackground(const ExtensionMessage&) = 0;
};

class PlatformStorage {
public:
    virtual ~PlatformStorage() = default;
    virtual Result<std::string> readText(const std::string& key) = 0;
    virtual Result<void> writeText(const std::string& key, const std::string& value) = 0;
};

class PlatformWebNnProvider {
public:
    virtual ~PlatformWebNnProvider() = default;

    virtual WebNnDeviceCapabilities queryDeviceCapabilities() = 0;
    virtual WebNnBackendStatus checkBackendStatus(WebNnBackend) = 0;

    virtual Result<void*> loadModel(const std::string& path, WebNnBackend) = 0;
    virtual void destroySession(void* nativeSession) = 0;
    virtual Result<void*> cloneSession(void* nativeSession) = 0;
    virtual Result<void> resetSession(void* nativeSession) = 0;

    virtual Result<InferenceOutput> runInference(
        void* nativeSession,
        const InferenceInput&,
        const SessionConfig&) = 0;

    virtual Result<void> runInferenceStream(
        void* nativeSession,
        const InferenceInput&,
        const SessionConfig&,
        StreamCallback) = 0;
};

class PlatformModelStorage {
public:
    virtual ~PlatformModelStorage() = default;

    virtual Result<CachedModel> lookup(const ModelId&) = 0;
    virtual Result<std::vector<CachedModel>> listCached() = 0;
    virtual Result<StorageQuota> queryQuota() = 0;
    virtual Result<CachedModel> store(const ModelId&,
                                       const std::string& sourcePath,
                                       const std::string& sha256) = 0;
    virtual Result<void> remove(const ModelId&) = 0;
    virtual Result<void> touchAccessTime(const ModelId&) = 0;
};

class PlatformModelDownloader {
public:
    virtual ~PlatformModelDownloader() = default;

    virtual Result<std::string> fetch(const std::string& url,
                                       const ModelId&,
                                       DownloadProgressCallback) = 0;
    virtual Result<void> cancel(const ModelId&) = 0;
    virtual Result<std::string> computeSha256(const std::string& filePath) = 0;
};

} // namespace ng

