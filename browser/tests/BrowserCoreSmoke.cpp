#include "extensions/ExtensionRegistry.h"
#include "extensions/ExtensionRuntime.h"
#include "sync/LoopbackSyncClient.h"
#include "tabs/BrowserCommandController.h"
#include "webauthn/WebAuthnController.h"

#include <cassert>

namespace {

ng::FrameContext trustworthyFrame()
{
    ng::FrameContext frame;
    frame.origin = { "https", "example.com", 0 };
    frame.topLevelOrigin = frame.origin;
    frame.isTopLevel = true;
    frame.hasTransientUserActivation = true;
    return frame;
}

class TestWebAuthnProvider final : public ng::PlatformWebAuthnProvider {
public:
    ng::Result<ng::WebAuthnAssertion> getAssertion(const ng::WebAuthnGetRequest& request) final
    {
        ng::WebAuthnAssertion assertion;
        assertion.credentialId = request.allowCredentials.empty() ? ng::ByteVector { 1, 2, 3 } : request.allowCredentials.front().id;
        assertion.authenticatorData = { 4, 5, 6 };
        assertion.clientDataJSON = { 7, 8, 9 };
        assertion.signature = { 10, 11, 12 };
        return ng::Result<ng::WebAuthnAssertion>::ok(std::move(assertion));
    }

    ng::Result<ng::WebAuthnAttestation> makeCredential(const ng::WebAuthnCreateRequest& request) final
    {
        ng::WebAuthnAttestation attestation;
        attestation.credentialId = request.userId.empty() ? ng::ByteVector { 9, 8, 7 } : request.userId;
        attestation.clientDataJSON = { 7, 8, 9 };
        attestation.attestationObject = { 10, 11, 12 };
        return ng::Result<ng::WebAuthnAttestation>::ok(std::move(attestation));
    }
};

void exerciseTabs()
{
    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);
    auto window = commands.newWindow(ng::TabStripMode::Vertical);
    auto tab = commands.newTab(window, "https://example.com", true);
    assert(tab);
    assert(state.window(window)->tabStripMode == ng::TabStripMode::Vertical);
    assert(state.tab(tab.value())->active);
    assert(commands.useHorizontalTabs(window));
    assert(state.window(window)->tabStripMode == ng::TabStripMode::Horizontal);
}

void exerciseExtensions()
{
    ng::ExtensionRegistry registry;
    ng::ExtensionManifest manifest;
    manifest.id = "test-extension";
    manifest.version = ng::ExtensionManifestVersion::ManifestV3;
    manifest.name = "Test Extension";
    manifest.versionString = "1.0.0";
    manifest.sidePanel.defaultPath = "sidepanel.html";
    assert(registry.install(manifest));

    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);
    ng::ExtensionRuntime runtime(registry, commands);
    assert(runtime.registerHandler("test-extension", "runtime.sendMessage", [](const ng::ExtensionMessage&) {
        return ng::Result<ng::ExtensionMessageResponse>::ok({ "ok" });
    }));

    ng::ExtensionMessage message;
    message.extensionId = "test-extension";
    message.frame = trustworthyFrame();
    message.channel = "runtime.sendMessage";
    auto response = runtime.dispatch(message);
    assert(response);
    assert(response.value().payload == "ok");
}

void exerciseWebAuthnCrossOriginHeuristic()
{
    ng::FrameContext nestedCrossSite;
    nestedCrossSite.origin = { "https", "evil.example", 0 };
    nestedCrossSite.topLevelOrigin = { "https", "example.com", 0 };
    nestedCrossSite.isTopLevel = false;
    nestedCrossSite.hasTransientUserActivation = true;
    assert(nestedCrossSite.includeCrossOriginClientDataMember());

    ng::FrameContext nestedSameSite;
    nestedSameSite.origin = { "https", "example.com", 0 };
    nestedSameSite.topLevelOrigin = { "https", "example.com", 0 };
    nestedSameSite.isTopLevel = false;
    nestedSameSite.hasTransientUserActivation = true;
    assert(!nestedSameSite.includeCrossOriginClientDataMember());

    ng::FrameContext sandboxed;
    sandboxed.origin = { "https", "example.com", 0 };
    sandboxed.topLevelOrigin = { "https", "example.com", 0 };
    sandboxed.isTopLevel = false;
    sandboxed.sameOriginWithAncestors = false;
    sandboxed.hasTransientUserActivation = true;
    assert(sandboxed.includeCrossOriginClientDataMember());
}

void exerciseWebAuthn()
{
    TestWebAuthnProvider provider;
    ng::WebAuthnController controller(provider);

    ng::WebAuthnGetRequest request;
    request.frame = trustworthyFrame();
    request.relyingPartyId = "example.com";
    request.challenge = ng::ByteVector(32, 7);

    auto assertion = controller.get(request);
    assert(assertion);
    assert(!assertion.value().signature.empty());

    ng::WebAuthnCreateRequest create;
    create.frame = trustworthyFrame();
    create.relyingPartyId = "example.com";
    create.relyingPartyName = "Example";
    create.challenge = ng::ByteVector(32, 3);
    create.userId = { 1, 2, 3, 4 };
    create.userName = "user@example.com";
    create.userDisplayName = "Example User";

    auto attestation = controller.make(std::move(create));
    assert(attestation);
    assert(!attestation.value().attestationObject.empty());
}

void exerciseSync()
{
    ng::LoopbackSyncServer server;
    ng::LoopbackSyncClient first("first");
    ng::LoopbackSyncClient second("second");

    first.trackDataType(ng::SyncDataType::Bookmarks);
    second.trackDataType(ng::SyncDataType::Bookmarks);

    first.upsertLocal(ng::SyncDataType::Bookmarks, "bookmark-a", "Example", "https://example.test");
    assert(first.sync(server) == ng::SyncResult::Success);
    assert(second.sync(server) == ng::SyncResult::Success);

    const auto id = ng::LoopbackSyncServer::createId(ng::SyncDataType::Bookmarks, "bookmark-a");
    auto synced = second.localRecord(id);
    assert(synced);
    assert(synced->name == "Example");
    assert(synced->payload == "https://example.test");
}

} // namespace

int main()
{
    exerciseTabs();
    exerciseExtensions();
    exerciseWebAuthnCrossOriginHeuristic();
    exerciseWebAuthn();
    exerciseSync();
    return 0;
}
