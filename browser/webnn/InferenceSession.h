#pragma once

#include "core/Result.h"
#include "webnn/WebNnTypes.h"

#include <memory>

namespace ng {

class PlatformWebNnProvider;

class InferenceSession {
public:
    static Result<std::unique_ptr<InferenceSession>> create(
        PlatformWebNnProvider&,
        const CachedModel&,
        const SessionConfig&);

    ~InferenceSession();

    Result<InferenceOutput> generate(const InferenceInput&);
    Result<void> generateStream(const InferenceInput&, StreamCallback);
    Result<std::unique_ptr<InferenceSession>> clone() const;

    unsigned currentContextLength() const { return m_contextLength; }
    unsigned maxContextLength() const { return m_config.maxTokens; }
    bool isContextFull() const { return m_contextLength >= m_config.maxTokens; }

    Result<void> resetContext();

    WebNnBackend activeBackend() const { return m_activeBackend; }

private:
    InferenceSession(PlatformWebNnProvider&, SessionConfig);

    PlatformWebNnProvider& m_provider;
    SessionConfig m_config;
    WebNnBackend m_activeBackend { WebNnBackend::CPU };

    void* m_nativeSession { nullptr };
    unsigned m_contextLength { 0 };
};

} // namespace ng
