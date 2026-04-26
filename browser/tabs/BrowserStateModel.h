#pragma once

#include "core/Result.h"

#include <cstdint>
#include <deque>
#include <functional>
#include <string>
#include <vector>

namespace ng {

using BrowserWindowId = uint64_t;
using BrowserTabId = uint64_t;
using BookmarkId = uint64_t;

enum class TabStripMode {
    Horizontal,
    Vertical,
};

enum class NavigationAction {
    GoBack,
    GoForward,
    Reload,
    StopLoading,
};

enum class ZoomDirection {
    In,
    Out,
    Reset,
};

enum class PermissionType {
    Camera,
    Microphone,
    Geolocation,
    Notifications,
};

enum class PermissionDecision {
    Allow,
    Deny,
    Dismiss,
};

struct NavEntry {
    std::string url;
    std::string title;
};

struct BrowserTab {
    BrowserTabId id { 0 };
    BrowserWindowId windowId { 0 };
    std::string url;
    std::string title;
    bool active { false };
    bool pinned { false };
    bool discarded { false };
    bool canGoBack { false };
    bool canGoForward { false };
    bool isLoading { false };
    double zoomLevel { 1.0 };
    std::string findQuery;
};

struct ClosedTabRecord {
    BrowserWindowId windowId { 0 };
    std::string url;
    std::string title;
    size_t index { 0 };
};

struct BookmarkEntry {
    BookmarkId id { 0 };
    std::string url;
    std::string title;
    std::string folder;
};

struct HistoryEntry {
    std::string url;
    std::string title;
    uint64_t visitTimeMs { 0 };
};

struct DownloadItem {
    uint64_t id { 0 };
    std::string url;
    std::string filename;
    std::string savePath;
    uint64_t receivedBytes { 0 };
    uint64_t totalBytes { 0 };
    bool complete { false };
    bool cancelled { false };
};

struct PermissionRequest {
    BrowserTabId tabId { 0 };
    PermissionType type;
    std::string origin;
};

struct BrowserWindow {
    BrowserWindowId id { 0 };
    TabStripMode tabStripMode { TabStripMode::Horizontal };
    std::vector<BrowserTabId> tabs;
    BrowserTabId activeTabId { 0 };
};

class BrowserStateModel {
public:
    BrowserWindowId createWindow(TabStripMode = TabStripMode::Horizontal);
    Result<BrowserTabId> createTab(BrowserWindowId, std::string url, bool activate);
    Result<void> closeTab(BrowserTabId);
    Result<void> activateTab(BrowserTabId);
    Result<void> moveTab(BrowserTabId, BrowserWindowId targetWindow, size_t targetIndex);
    Result<void> setTabStripMode(BrowserWindowId, TabStripMode);

    // Navigation
    Result<void> navigateTab(BrowserTabId, std::string url);
    Result<void> navigationAction(BrowserTabId, NavigationAction);
    Result<void> updateTabNavState(BrowserTabId, bool canGoBack, bool canGoForward, bool isLoading);
    Result<void> updateTabTitle(BrowserTabId, std::string title);

    // Tab restore
    Result<BrowserTabId> restoreLastClosedTab(BrowserWindowId);
    const std::deque<ClosedTabRecord>& closedTabStack() const { return m_closedTabs; }

    // Find-in-page
    Result<void> findInPage(BrowserTabId, std::string query);
    Result<void> dismissFind(BrowserTabId);

    // Zoom
    Result<void> zoomTab(BrowserTabId, ZoomDirection);

    // Bookmarks
    BookmarkId addBookmark(std::string url, std::string title, std::string folder = "");
    Result<void> removeBookmark(BookmarkId);
    const std::vector<BookmarkEntry>& bookmarks() const { return m_bookmarks; }

    // History
    void addHistoryEntry(std::string url, std::string title);
    const std::deque<HistoryEntry>& history() const { return m_history; }
    void clearHistory();

    // Downloads
    uint64_t addDownload(std::string url, std::string filename, std::string savePath);
    Result<void> updateDownloadProgress(uint64_t downloadId, uint64_t receivedBytes, uint64_t totalBytes);
    Result<void> completeDownload(uint64_t downloadId);
    Result<void> cancelDownload(uint64_t downloadId);
    const std::vector<DownloadItem>& downloads() const { return m_downloads; }

    // Permissions
    void addPermissionRequest(BrowserTabId, PermissionType, std::string origin);
    Result<void> resolvePermission(BrowserTabId, PermissionType, PermissionDecision);
    const std::vector<PermissionRequest>& pendingPermissions() const { return m_pendingPermissions; }

    const BrowserWindow* window(BrowserWindowId) const;
    const BrowserTab* tab(BrowserTabId) const;
    std::vector<BrowserWindow> windows() const { return m_windows; }
    std::vector<BrowserTab> tabs() const { return m_tabs; }

    // Callbacks for shell integration
    using NavigationCallback = std::function<void(BrowserTabId, const std::string& url)>;
    using NavActionCallback = std::function<void(BrowserTabId, NavigationAction)>;
    using FindCallback = std::function<void(BrowserTabId, const std::string& query)>;
    using ZoomCallback = std::function<void(BrowserTabId, double zoomLevel)>;
    using DownloadActionCallback = std::function<void(uint64_t downloadId, bool cancel)>;
    using PrintCallback = std::function<void(BrowserTabId)>;

    void setNavigationCallback(NavigationCallback cb) { m_onNavigate = std::move(cb); }
    void setNavActionCallback(NavActionCallback cb) { m_onNavAction = std::move(cb); }
    void setFindCallback(FindCallback cb) { m_onFind = std::move(cb); }
    void setZoomCallback(ZoomCallback cb) { m_onZoom = std::move(cb); }
    void setPrintCallback(PrintCallback cb) { m_onPrint = std::move(cb); }

    // Print
    Result<void> printPage(BrowserTabId);

private:
    BrowserWindow* mutableWindow(BrowserWindowId);
    BrowserTab* mutableTab(BrowserTabId);
    void removeTabFromWindow(BrowserWindow&, BrowserTabId);
    void setActiveTab(BrowserWindow&, BrowserTabId);

    BrowserWindowId m_nextWindowId { 1 };
    BrowserTabId m_nextTabId { 1 };
    BookmarkId m_nextBookmarkId { 1 };
    uint64_t m_nextDownloadId { 1 };

    std::vector<BrowserWindow> m_windows;
    std::vector<BrowserTab> m_tabs;
    std::deque<ClosedTabRecord> m_closedTabs;
    std::vector<BookmarkEntry> m_bookmarks;
    std::deque<HistoryEntry> m_history;
    std::vector<DownloadItem> m_downloads;
    std::vector<PermissionRequest> m_pendingPermissions;

    static constexpr size_t kMaxClosedTabs = 25;
    static constexpr size_t kMaxHistory = 1000;

    NavigationCallback m_onNavigate;
    NavActionCallback m_onNavAction;
    FindCallback m_onFind;
    ZoomCallback m_onZoom;
    PrintCallback m_onPrint;
};

} // namespace ng

