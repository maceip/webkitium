#include "webnn/InferenceSession.h"
#include "platform/PlatformAdapters.h"

namespace ng {

Result<std::unique_ptr<InferenceSession>> InferenceSession::create(
    PlatformWebNnProvider& provider,
    const CachedModel& model,
    const SessionConfig& config)
{
    auto session = std::unique_ptr<InferenceSession>(
        new InferenceSession(provider, config));

    auto loadResult = provider.loadModel(model.localPath, config.backend);
    if (!loadResult)
        return Result<std::unique_ptr<InferenceSession>>::fail(loadResult.error());

    session->m_nativeSession = loadResult.value();
    session->m_activeBackend = config.backend;

    return Result<std::unique_ptr<InferenceSession>>::ok(std::move(session));
}

InferenceSession::InferenceSession(PlatformWebNnProvider& provider,
                                     SessionConfig config)
    : m_provider(provider)
    , m_config(std::move(config))
{
}

InferenceSession::~InferenceSession()
{
    if (m_nativeSession)
        m_provider.destroySession(m_nativeSession);
}

Result<InferenceOutput> InferenceSession::generate(const InferenceInput& input)
{
    if (!m_nativeSession)
        return Result<InferenceOutput>::fail({ ErrorCode::InternalError,
            "No active session" });

    if (isContextFull())
        return Result<InferenceOutput>::fail({ ErrorCode::InvalidArgument,
            "Context window full" });

    auto result = m_provider.runInference(m_nativeSession, input, m_config);
    if (result)
        m_contextLength += 1;

    return result;
}

Result<void> InferenceSession::generateStream(const InferenceInput& input,
                                                StreamCallback callback)
{
    if (!m_nativeSession)
        return Result<void>::fail({ ErrorCode::InternalError,
            "No active session" });

    if (isContextFull())
        return Result<void>::fail({ ErrorCode::InvalidArgument,
            "Context window full" });

    auto result = m_provider.runInferenceStream(
        m_nativeSession, input, m_config, std::move(callback));
    if (result)
        m_contextLength += 1;

    return result;
}

Result<std::unique_ptr<InferenceSession>> InferenceSession::clone() const
{
    if (!m_nativeSession)
        return Result<std::unique_ptr<InferenceSession>>::fail(
            { ErrorCode::InternalError, "No active session to clone" });

    auto clonedSession = std::unique_ptr<InferenceSession>(
        new InferenceSession(m_provider, m_config));

    auto cloneResult = m_provider.cloneSession(m_nativeSession);
    if (!cloneResult)
        return Result<std::unique_ptr<InferenceSession>>::fail(
            cloneResult.error());

    clonedSession->m_nativeSession = cloneResult.value();
    clonedSession->m_activeBackend = m_activeBackend;
    clonedSession->m_contextLength = m_contextLength;

    return Result<std::unique_ptr<InferenceSession>>::ok(
        std::move(clonedSession));
}

Result<void> InferenceSession::resetContext()
{
    if (!m_nativeSession)
        return Result<void>::fail({ ErrorCode::InternalError,
            "No active session" });

    auto result = m_provider.resetSession(m_nativeSession);
    if (result)
        m_contextLength = 0;

    return result;
}

} // namespace ng
