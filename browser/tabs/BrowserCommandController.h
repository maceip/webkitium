#pragma once

#include "tabs/BrowserStateModel.h"

namespace ng {

class BrowserCommandController {
public:
    explicit BrowserCommandController(BrowserStateModel&);

    // Window / tab management
    BrowserWindowId newWindow(TabStripMode);
    Result<BrowserTabId> newTab(BrowserWindowId, std::string url, bool activate = true);
    Result<void> closeTab(BrowserTabId);
    Result<void> selectTab(BrowserTabId);
    Result<void> moveTab(BrowserTabId, BrowserWindowId, size_t targetIndex);
    Result<void> useHorizontalTabs(BrowserWindowId);
    Result<void> useVerticalTabs(BrowserWindowId);

    // Navigation (Tier 1)
    Result<void> navigateActiveTab(BrowserWindowId, std::string url);
    Result<void> goBack(BrowserTabId);
    Result<void> goForward(BrowserTabId);
    Result<void> reload(BrowserTabId);
    Result<void> stopLoading(BrowserTabId);

    // Tab restore (Tier 2)
    Result<BrowserTabId> restoreClosedTab(BrowserWindowId);

    // Find-in-page (Tier 2)
    Result<void> findInPage(BrowserTabId, std::string query);
    Result<void> findNext(BrowserTabId);
    Result<void> findPrevious(BrowserTabId);
    Result<void> dismissFind(BrowserTabId);

    // Zoom (Tier 2)
    Result<void> zoomIn(BrowserTabId);
    Result<void> zoomOut(BrowserTabId);
    Result<void> zoomReset(BrowserTabId);

    // Bookmarks (Tier 2)
    BookmarkId addBookmark(std::string url, std::string title, std::string folder = "");
    Result<void> removeBookmark(BookmarkId);

    // Print (Tier 2)
    Result<void> printPage(BrowserTabId);

    // Permissions (Tier 2)
    Result<void> resolvePermission(BrowserTabId, PermissionType, PermissionDecision);

    BrowserStateModel& state() { return m_state; }

private:
    BrowserStateModel& m_state;
};

} // namespace ng

