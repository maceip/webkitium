#include "tabs/BrowserCommandController.h"

namespace ng {

BrowserCommandController::BrowserCommandController(BrowserStateModel& state)
    : m_state(state)
{
}

BrowserWindowId BrowserCommandController::newWindow(TabStripMode mode)
{
    return m_state.createWindow(mode);
}

Result<BrowserTabId> BrowserCommandController::newTab(BrowserWindowId windowId, std::string url, bool activate)
{
    return m_state.createTab(windowId, std::move(url), activate);
}

Result<void> BrowserCommandController::closeTab(BrowserTabId tabId)
{
    return m_state.closeTab(tabId);
}

Result<void> BrowserCommandController::selectTab(BrowserTabId tabId)
{
    return m_state.activateTab(tabId);
}

Result<void> BrowserCommandController::moveTab(BrowserTabId tabId, BrowserWindowId windowId, size_t targetIndex)
{
    return m_state.moveTab(tabId, windowId, targetIndex);
}

Result<void> BrowserCommandController::useHorizontalTabs(BrowserWindowId windowId)
{
    return m_state.setTabStripMode(windowId, TabStripMode::Horizontal);
}

Result<void> BrowserCommandController::useVerticalTabs(BrowserWindowId windowId)
{
    return m_state.setTabStripMode(windowId, TabStripMode::Vertical);
}

// -- Navigation (Tier 1) --

Result<void> BrowserCommandController::navigateActiveTab(BrowserWindowId windowId, std::string url)
{
    const auto* win = m_state.window(windowId);
    if (!win)
        return Result<void>::fail({ ErrorCode::NotFound, "window not found" });
    if (win->activeTabId == 0)
        return Result<void>::fail({ ErrorCode::NotFound, "no active tab" });
    return m_state.navigateTab(win->activeTabId, std::move(url));
}

Result<void> BrowserCommandController::goBack(BrowserTabId tabId)
{
    return m_state.navigationAction(tabId, NavigationAction::GoBack);
}

Result<void> BrowserCommandController::goForward(BrowserTabId tabId)
{
    return m_state.navigationAction(tabId, NavigationAction::GoForward);
}

Result<void> BrowserCommandController::reload(BrowserTabId tabId)
{
    return m_state.navigationAction(tabId, NavigationAction::Reload);
}

Result<void> BrowserCommandController::stopLoading(BrowserTabId tabId)
{
    return m_state.navigationAction(tabId, NavigationAction::StopLoading);
}

// -- Tab restore (Tier 2) --

Result<BrowserTabId> BrowserCommandController::restoreClosedTab(BrowserWindowId windowId)
{
    return m_state.restoreLastClosedTab(windowId);
}

// -- Find-in-page (Tier 2) --

Result<void> BrowserCommandController::findInPage(BrowserTabId tabId, std::string query)
{
    return m_state.findInPage(tabId, std::move(query));
}

Result<void> BrowserCommandController::findNext(BrowserTabId tabId)
{
    const auto* tab = m_state.tab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });
    return m_state.findInPage(tabId, tab->findQuery);
}

Result<void> BrowserCommandController::findPrevious(BrowserTabId tabId)
{
    const auto* tab = m_state.tab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });
    return m_state.findInPage(tabId, tab->findQuery);
}

Result<void> BrowserCommandController::dismissFind(BrowserTabId tabId)
{
    return m_state.dismissFind(tabId);
}

// -- Zoom (Tier 2) --

Result<void> BrowserCommandController::zoomIn(BrowserTabId tabId)
{
    return m_state.zoomTab(tabId, ZoomDirection::In);
}

Result<void> BrowserCommandController::zoomOut(BrowserTabId tabId)
{
    return m_state.zoomTab(tabId, ZoomDirection::Out);
}

Result<void> BrowserCommandController::zoomReset(BrowserTabId tabId)
{
    return m_state.zoomTab(tabId, ZoomDirection::Reset);
}

// -- Bookmarks (Tier 2) --

BookmarkId BrowserCommandController::addBookmark(std::string url, std::string title, std::string folder)
{
    return m_state.addBookmark(std::move(url), std::move(title), std::move(folder));
}

Result<void> BrowserCommandController::removeBookmark(BookmarkId id)
{
    return m_state.removeBookmark(id);
}

// -- Print (Tier 2) --

Result<void> BrowserCommandController::printPage(BrowserTabId tabId)
{
    return m_state.printPage(tabId);
}

// -- Permissions (Tier 2) --

Result<void> BrowserCommandController::resolvePermission(BrowserTabId tabId, PermissionType type, PermissionDecision decision)
{
    return m_state.resolvePermission(tabId, type, decision);
}

} // namespace ng

