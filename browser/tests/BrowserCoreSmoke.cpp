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

void exerciseNavigation()
{
    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);

    auto win = commands.newWindow(ng::TabStripMode::Horizontal);
    auto tabResult = commands.newTab(win, "https://start.test", true);
    assert(tabResult);
    auto tabId = tabResult.value();

    // navigateActiveTab dispatches through model
    bool navCallbackFired = false;
    std::string navigatedUrl;
    state.setNavigationCallback([&](ng::BrowserTabId id, const std::string& url) {
        navCallbackFired = true;
        navigatedUrl = url;
        assert(id == tabId);
    });
    assert(commands.navigateActiveTab(win, "https://second.test"));
    assert(navCallbackFired);
    assert(navigatedUrl == "https://second.test");
    assert(state.tab(tabId)->url == "https://second.test");
    assert(state.tab(tabId)->isLoading);

    // updateTabNavState
    assert(state.updateTabNavState(tabId, true, false, false));
    assert(state.tab(tabId)->canGoBack);
    assert(!state.tab(tabId)->canGoForward);
    assert(!state.tab(tabId)->isLoading);

    // goBack / goForward
    bool actionFired = false;
    ng::NavigationAction firedAction {};
    state.setNavActionCallback([&](ng::BrowserTabId, ng::NavigationAction a) {
        actionFired = true;
        firedAction = a;
    });
    assert(commands.goBack(tabId));
    assert(actionFired);
    assert(firedAction == ng::NavigationAction::GoBack);

    actionFired = false;
    assert(!commands.goForward(tabId)); // canGoForward is false

    state.updateTabNavState(tabId, true, true, false);
    assert(commands.goForward(tabId));
    assert(firedAction == ng::NavigationAction::GoForward);

    // reload
    actionFired = false;
    assert(commands.reload(tabId));
    assert(firedAction == ng::NavigationAction::Reload);

    // updateTabTitle
    assert(state.updateTabTitle(tabId, "Hello World"));
    assert(state.tab(tabId)->title == "Hello World");
}

void exerciseTabRestore()
{
    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);

    auto win = commands.newWindow(ng::TabStripMode::Horizontal);
    auto t1 = commands.newTab(win, "https://a.test", true);
    auto t2 = commands.newTab(win, "https://b.test", false);
    assert(t1 && t2);
    assert(state.tabs().size() == 2);

    // close t2 → should land on closed stack
    assert(commands.closeTab(t2.value()));
    assert(state.tabs().size() == 1);
    assert(state.closedTabStack().size() == 1);
    assert(state.closedTabStack().front().url == "https://b.test");

    // restore
    auto restored = commands.restoreClosedTab(win);
    assert(restored);
    assert(state.tabs().size() == 2);
    assert(state.tab(restored.value())->url == "https://b.test");
    assert(state.closedTabStack().empty());

    // restore when empty fails
    auto bad = commands.restoreClosedTab(win);
    assert(!bad);
}

void exerciseFindInPage()
{
    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);

    auto win = commands.newWindow(ng::TabStripMode::Horizontal);
    auto tabResult = commands.newTab(win, "https://find.test", true);
    assert(tabResult);
    auto tabId = tabResult.value();

    bool findFired = false;
    std::string findQuery;
    state.setFindCallback([&](ng::BrowserTabId, const std::string& q) {
        findFired = true;
        findQuery = q;
    });

    assert(commands.findInPage(tabId, "hello"));
    assert(findFired);
    assert(findQuery == "hello");
    assert(state.tab(tabId)->findQuery == "hello");

    findFired = false;
    assert(commands.dismissFind(tabId));
    assert(findFired);
    assert(findQuery.empty());
    assert(state.tab(tabId)->findQuery.empty());
}

void exerciseZoom()
{
    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);

    auto win = commands.newWindow(ng::TabStripMode::Horizontal);
    auto tabResult = commands.newTab(win, "https://zoom.test", true);
    assert(tabResult);
    auto tabId = tabResult.value();

    assert(state.tab(tabId)->zoomLevel == 1.0);

    double reportedZoom = 0;
    state.setZoomCallback([&](ng::BrowserTabId, double z) { reportedZoom = z; });

    assert(commands.zoomIn(tabId));
    assert(reportedZoom > 1.0);
    assert(state.tab(tabId)->zoomLevel > 1.0);

    assert(commands.zoomReset(tabId));
    assert(state.tab(tabId)->zoomLevel == 1.0);

    assert(commands.zoomOut(tabId));
    assert(state.tab(tabId)->zoomLevel < 1.0);

    // clamp: zoom out many times should not go below 0.3
    for (int i = 0; i < 100; ++i)
        commands.zoomOut(tabId);
    assert(state.tab(tabId)->zoomLevel >= 0.3);

    // clamp: zoom in many times should not exceed 3.0
    for (int i = 0; i < 100; ++i)
        commands.zoomIn(tabId);
    assert(state.tab(tabId)->zoomLevel <= 3.0);
}

void exerciseBookmarks()
{
    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);

    assert(state.bookmarks().empty());

    auto id1 = commands.addBookmark("https://a.test", "Site A", "folder1");
    auto id2 = commands.addBookmark("https://b.test", "Site B");
    assert(state.bookmarks().size() == 2);
    assert(state.bookmarks()[0].url == "https://a.test");
    assert(state.bookmarks()[0].folder == "folder1");
    assert(state.bookmarks()[1].title == "Site B");

    assert(commands.removeBookmark(id1));
    assert(state.bookmarks().size() == 1);
    assert(state.bookmarks()[0].url == "https://b.test");

    // removing nonexistent fails
    assert(!commands.removeBookmark(9999));
}

void exerciseHistory()
{
    ng::BrowserStateModel state;

    assert(state.history().empty());

    state.addHistoryEntry("https://x.test", "X");
    state.addHistoryEntry("https://y.test", "Y");
    assert(state.history().size() == 2);
    assert(state.history().front().url == "https://y.test"); // most recent first

    // empty url should be ignored
    state.addHistoryEntry("", "Empty");
    assert(state.history().size() == 2);

    state.clearHistory();
    assert(state.history().empty());
}

void exerciseDownloads()
{
    ng::BrowserStateModel state;

    auto dlId = state.addDownload("https://dl.test/file.zip", "file.zip", "/tmp/file.zip");
    assert(state.downloads().size() == 1);
    assert(state.downloads()[0].url == "https://dl.test/file.zip");
    assert(!state.downloads()[0].complete);

    assert(state.updateDownloadProgress(dlId, 500, 1000));
    assert(state.downloads()[0].receivedBytes == 500);
    assert(state.downloads()[0].totalBytes == 1000);

    assert(state.completeDownload(dlId));
    assert(state.downloads()[0].complete);

    // nonexistent download
    assert(!state.updateDownloadProgress(9999, 0, 0));
    assert(!state.completeDownload(9999));
    assert(!state.cancelDownload(9999));

    auto dlId2 = state.addDownload("https://dl.test/other.zip", "other.zip", "/tmp/other.zip");
    assert(state.cancelDownload(dlId2));
    assert(state.downloads()[1].cancelled);
}

void exercisePermissions()
{
    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);

    auto win = commands.newWindow(ng::TabStripMode::Horizontal);
    auto tabResult = commands.newTab(win, "https://perms.test", true);
    assert(tabResult);
    auto tabId = tabResult.value();

    assert(state.pendingPermissions().empty());

    state.addPermissionRequest(tabId, ng::PermissionType::Camera, "https://perms.test");
    assert(state.pendingPermissions().size() == 1);
    assert(state.pendingPermissions()[0].type == ng::PermissionType::Camera);

    assert(commands.resolvePermission(tabId, ng::PermissionType::Camera, ng::PermissionDecision::Allow));
    assert(state.pendingPermissions().empty());

    // resolving nonexistent fails
    assert(!commands.resolvePermission(tabId, ng::PermissionType::Microphone, ng::PermissionDecision::Deny));
}

void exercisePrint()
{
    ng::BrowserStateModel state;
    ng::BrowserCommandController commands(state);

    auto win = commands.newWindow(ng::TabStripMode::Horizontal);
    auto tabResult = commands.newTab(win, "https://print.test", true);
    assert(tabResult);
    auto tabId = tabResult.value();

    bool printFired = false;
    state.setPrintCallback([&](ng::BrowserTabId id) {
        printFired = true;
        assert(id == tabId);
    });

    assert(commands.printPage(tabId));
    assert(printFired);

    // nonexistent tab fails
    assert(!commands.printPage(9999));
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
    exerciseNavigation();
    exerciseTabRestore();
    exerciseFindInPage();
    exerciseZoom();
    exerciseBookmarks();
    exerciseHistory();
    exerciseDownloads();
    exercisePermissions();
    exercisePrint();
    exerciseExtensions();
    exerciseWebAuthn();
    exerciseSync();
    return 0;
}
