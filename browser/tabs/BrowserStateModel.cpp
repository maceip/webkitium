#include "tabs/BrowserStateModel.h"

#include <algorithm>
#include <chrono>

namespace ng {

BrowserWindowId BrowserStateModel::createWindow(TabStripMode mode)
{
    BrowserWindow window;
    window.id = m_nextWindowId++;
    window.tabStripMode = mode;
    m_windows.push_back(window);
    return window.id;
}

Result<BrowserTabId> BrowserStateModel::createTab(BrowserWindowId windowId, std::string url, bool activate)
{
    auto* targetWindow = mutableWindow(windowId);
    if (!targetWindow)
        return Result<BrowserTabId>::fail({ ErrorCode::NotFound, "window not found" });

    BrowserTab tab;
    tab.id = m_nextTabId++;
    tab.windowId = windowId;
    tab.url = std::move(url);
    tab.active = activate || targetWindow->tabs.empty();

    targetWindow->tabs.push_back(tab.id);
    m_tabs.push_back(tab);

    if (tab.active)
        setActiveTab(*targetWindow, tab.id);

    return Result<BrowserTabId>::ok(tab.id);
}

Result<void> BrowserStateModel::closeTab(BrowserTabId tabId)
{
    auto tabIt = std::find_if(m_tabs.begin(), m_tabs.end(), [tabId](const auto& tab) { return tab.id == tabId; });
    if (tabIt == m_tabs.end())
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    auto* ownerWindow = mutableWindow(tabIt->windowId);
    size_t tabIndex = 0;
    if (ownerWindow) {
        auto posIt = std::find(ownerWindow->tabs.begin(), ownerWindow->tabs.end(), tabId);
        if (posIt != ownerWindow->tabs.end())
            tabIndex = static_cast<size_t>(std::distance(ownerWindow->tabs.begin(), posIt));

        ClosedTabRecord record;
        record.windowId = tabIt->windowId;
        record.url = tabIt->url;
        record.title = tabIt->title;
        record.index = tabIndex;
        m_closedTabs.push_front(record);
        if (m_closedTabs.size() > kMaxClosedTabs)
            m_closedTabs.pop_back();

        removeTabFromWindow(*ownerWindow, tabId);
        if (ownerWindow->activeTabId == tabId)
            ownerWindow->activeTabId = ownerWindow->tabs.empty() ? 0 : ownerWindow->tabs.front();
    }

    m_tabs.erase(tabIt);
    if (ownerWindow && ownerWindow->activeTabId)
        setActiveTab(*ownerWindow, ownerWindow->activeTabId);

    return Result<void>::ok();
}

Result<void> BrowserStateModel::activateTab(BrowserTabId tabId)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    auto* ownerWindow = mutableWindow(tab->windowId);
    if (!ownerWindow)
        return Result<void>::fail({ ErrorCode::NotFound, "window not found" });

    setActiveTab(*ownerWindow, tabId);
    return Result<void>::ok();
}

Result<void> BrowserStateModel::moveTab(BrowserTabId tabId, BrowserWindowId targetWindowId, size_t targetIndex)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    auto* sourceWindow = mutableWindow(tab->windowId);
    auto* targetWindow = mutableWindow(targetWindowId);
    if (!sourceWindow || !targetWindow)
        return Result<void>::fail({ ErrorCode::NotFound, "window not found" });

    removeTabFromWindow(*sourceWindow, tabId);
    targetIndex = std::min(targetIndex, targetWindow->tabs.size());
    targetWindow->tabs.insert(targetWindow->tabs.begin() + static_cast<std::vector<BrowserTabId>::difference_type>(targetIndex), tabId);
    tab->windowId = targetWindowId;

    if (sourceWindow->activeTabId == tabId)
        sourceWindow->activeTabId = sourceWindow->tabs.empty() ? 0 : sourceWindow->tabs.front();

    setActiveTab(*targetWindow, tabId);
    return Result<void>::ok();
}

Result<void> BrowserStateModel::setTabStripMode(BrowserWindowId windowId, TabStripMode mode)
{
    auto* targetWindow = mutableWindow(windowId);
    if (!targetWindow)
        return Result<void>::fail({ ErrorCode::NotFound, "window not found" });

    targetWindow->tabStripMode = mode;
    return Result<void>::ok();
}

// -- Navigation --

Result<void> BrowserStateModel::navigateTab(BrowserTabId tabId, std::string url)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    tab->url = url;
    tab->isLoading = true;
    addHistoryEntry(url, tab->title);

    if (m_onNavigate)
        m_onNavigate(tabId, url);

    return Result<void>::ok();
}

Result<void> BrowserStateModel::navigationAction(BrowserTabId tabId, NavigationAction action)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    if (action == NavigationAction::GoBack && !tab->canGoBack)
        return Result<void>::fail({ ErrorCode::InvalidArgument, "cannot go back" });
    if (action == NavigationAction::GoForward && !tab->canGoForward)
        return Result<void>::fail({ ErrorCode::InvalidArgument, "cannot go forward" });

    if (m_onNavAction)
        m_onNavAction(tabId, action);

    return Result<void>::ok();
}

Result<void> BrowserStateModel::updateTabNavState(BrowserTabId tabId, bool canGoBack, bool canGoForward, bool isLoading)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    tab->canGoBack = canGoBack;
    tab->canGoForward = canGoForward;
    tab->isLoading = isLoading;
    return Result<void>::ok();
}

Result<void> BrowserStateModel::updateTabTitle(BrowserTabId tabId, std::string title)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    tab->title = std::move(title);
    return Result<void>::ok();
}

// -- Tab restore --

Result<BrowserTabId> BrowserStateModel::restoreLastClosedTab(BrowserWindowId windowId)
{
    if (m_closedTabs.empty())
        return Result<BrowserTabId>::fail({ ErrorCode::NotFound, "no closed tabs to restore" });

    auto record = m_closedTabs.front();
    m_closedTabs.pop_front();

    auto targetWinId = mutableWindow(record.windowId) ? record.windowId : windowId;
    return createTab(targetWinId, std::move(record.url), true);
}

// -- Find-in-page --

Result<void> BrowserStateModel::findInPage(BrowserTabId tabId, std::string query)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    tab->findQuery = query;
    if (m_onFind)
        m_onFind(tabId, query);

    return Result<void>::ok();
}

Result<void> BrowserStateModel::dismissFind(BrowserTabId tabId)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    tab->findQuery.clear();
    if (m_onFind)
        m_onFind(tabId, "");

    return Result<void>::ok();
}

// -- Zoom --

Result<void> BrowserStateModel::zoomTab(BrowserTabId tabId, ZoomDirection direction)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });

    switch (direction) {
    case ZoomDirection::In:
        tab->zoomLevel = std::min(tab->zoomLevel + 0.1, 3.0);
        break;
    case ZoomDirection::Out:
        tab->zoomLevel = std::max(tab->zoomLevel - 0.1, 0.3);
        break;
    case ZoomDirection::Reset:
        tab->zoomLevel = 1.0;
        break;
    }

    if (m_onZoom)
        m_onZoom(tabId, tab->zoomLevel);

    return Result<void>::ok();
}

// -- Bookmarks --

BookmarkId BrowserStateModel::addBookmark(std::string url, std::string title, std::string folder)
{
    BookmarkEntry entry;
    entry.id = m_nextBookmarkId++;
    entry.url = std::move(url);
    entry.title = std::move(title);
    entry.folder = std::move(folder);
    m_bookmarks.push_back(entry);
    return entry.id;
}

Result<void> BrowserStateModel::removeBookmark(BookmarkId bookmarkId)
{
    auto it = std::find_if(m_bookmarks.begin(), m_bookmarks.end(),
        [bookmarkId](const auto& b) { return b.id == bookmarkId; });
    if (it == m_bookmarks.end())
        return Result<void>::fail({ ErrorCode::NotFound, "bookmark not found" });
    m_bookmarks.erase(it);
    return Result<void>::ok();
}

// -- History --

void BrowserStateModel::addHistoryEntry(std::string url, std::string title)
{
    if (url.empty())
        return;

    auto now = std::chrono::system_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();

    HistoryEntry entry;
    entry.url = std::move(url);
    entry.title = std::move(title);
    entry.visitTimeMs = static_cast<uint64_t>(ms);
    m_history.push_front(entry);

    if (m_history.size() > kMaxHistory)
        m_history.pop_back();
}

void BrowserStateModel::clearHistory()
{
    m_history.clear();
}

// -- Downloads --

uint64_t BrowserStateModel::addDownload(std::string url, std::string filename, std::string savePath)
{
    DownloadItem item;
    item.id = m_nextDownloadId++;
    item.url = std::move(url);
    item.filename = std::move(filename);
    item.savePath = std::move(savePath);
    m_downloads.push_back(item);
    return item.id;
}

Result<void> BrowserStateModel::updateDownloadProgress(uint64_t downloadId, uint64_t receivedBytes, uint64_t totalBytes)
{
    auto it = std::find_if(m_downloads.begin(), m_downloads.end(),
        [downloadId](const auto& d) { return d.id == downloadId; });
    if (it == m_downloads.end())
        return Result<void>::fail({ ErrorCode::NotFound, "download not found" });
    it->receivedBytes = receivedBytes;
    it->totalBytes = totalBytes;
    return Result<void>::ok();
}

Result<void> BrowserStateModel::completeDownload(uint64_t downloadId)
{
    auto it = std::find_if(m_downloads.begin(), m_downloads.end(),
        [downloadId](const auto& d) { return d.id == downloadId; });
    if (it == m_downloads.end())
        return Result<void>::fail({ ErrorCode::NotFound, "download not found" });
    it->complete = true;
    return Result<void>::ok();
}

Result<void> BrowserStateModel::cancelDownload(uint64_t downloadId)
{
    auto it = std::find_if(m_downloads.begin(), m_downloads.end(),
        [downloadId](const auto& d) { return d.id == downloadId; });
    if (it == m_downloads.end())
        return Result<void>::fail({ ErrorCode::NotFound, "download not found" });
    it->cancelled = true;
    return Result<void>::ok();
}

// -- Permissions --

void BrowserStateModel::addPermissionRequest(BrowserTabId tabId, PermissionType type, std::string origin)
{
    PermissionRequest req;
    req.tabId = tabId;
    req.type = type;
    req.origin = std::move(origin);
    m_pendingPermissions.push_back(req);
}

Result<void> BrowserStateModel::resolvePermission(BrowserTabId tabId, PermissionType type, PermissionDecision)
{
    auto it = std::find_if(m_pendingPermissions.begin(), m_pendingPermissions.end(),
        [tabId, type](const auto& p) { return p.tabId == tabId && p.type == type; });
    if (it == m_pendingPermissions.end())
        return Result<void>::fail({ ErrorCode::NotFound, "no pending permission request" });
    m_pendingPermissions.erase(it);
    return Result<void>::ok();
}

// -- Print --

Result<void> BrowserStateModel::printPage(BrowserTabId tabId)
{
    auto* tab = mutableTab(tabId);
    if (!tab)
        return Result<void>::fail({ ErrorCode::NotFound, "tab not found" });
    if (m_onPrint)
        m_onPrint(tabId);
    return Result<void>::ok();
}

// -- Query --

const BrowserWindow* BrowserStateModel::window(BrowserWindowId id) const
{
    auto it = std::find_if(m_windows.begin(), m_windows.end(), [id](const auto& window) { return window.id == id; });
    return it == m_windows.end() ? nullptr : &*it;
}

const BrowserTab* BrowserStateModel::tab(BrowserTabId id) const
{
    auto it = std::find_if(m_tabs.begin(), m_tabs.end(), [id](const auto& tab) { return tab.id == id; });
    return it == m_tabs.end() ? nullptr : &*it;
}

BrowserWindow* BrowserStateModel::mutableWindow(BrowserWindowId id)
{
    auto it = std::find_if(m_windows.begin(), m_windows.end(), [id](const auto& window) { return window.id == id; });
    return it == m_windows.end() ? nullptr : &*it;
}

BrowserTab* BrowserStateModel::mutableTab(BrowserTabId id)
{
    auto it = std::find_if(m_tabs.begin(), m_tabs.end(), [id](const auto& tab) { return tab.id == id; });
    return it == m_tabs.end() ? nullptr : &*it;
}

void BrowserStateModel::removeTabFromWindow(BrowserWindow& window, BrowserTabId tabId)
{
    window.tabs.erase(std::remove(window.tabs.begin(), window.tabs.end(), tabId), window.tabs.end());
}

void BrowserStateModel::setActiveTab(BrowserWindow& window, BrowserTabId tabId)
{
    window.activeTabId = tabId;
    for (auto& tab : m_tabs)
        tab.active = tab.windowId == window.id && tab.id == tabId;
}

} // namespace ng

