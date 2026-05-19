package org.webkitium.android.ui

import org.wpewebkit.wpeview.WPEView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

/**
 * Shared state for the browser shell. Lifted out of any specific layout
 * (compact vs expanded) so the two layouts read the same model. Tabs,
 * URL bar text, autocomplete state, bookmarks, and find state all live
 * here.
 *
 * Per-tab WebView instances are held by reference — Compose doesn't
 * "own" them, the BrowserScreen layouts mount the active one via
 * AndroidView.
 */
class BrowserState {
    val tabs = mutableStateListOf<TabModel>()
    var activeTabIndex by mutableStateOf(0)

    /** Mirrors the active tab's URL. Page-load events update this when
     *  the URL bar is not focused; user typing updates it directly. */
    var urlInput by mutableStateOf("")
    var isUrlFocused by mutableStateOf(false)

    /** Autocomplete state — in-memory recent-URLs prefix match for now.
     *  TODO(features.yaml#url_autocomplete): wire SuggestionsBridge.kt
     *  to wk_suggestions_query once the Android JNI bridge for
     *  suggestions is added. */
    val recentUrls = mutableStateListOf<String>()
    var autocompleteResults by mutableStateOf<List<String>>(emptyList())

    /** Bookmarks. TODO(features.yaml#bookmarks_persist): wire to
     *  wk_suggestions_bookmarks_flat + wk_suggestions_set_bookmarked. */
    val bookmarks = mutableStateListOf<BookmarkRow>()

    /** Find on page. */
    var isFindOpen by mutableStateOf(false)
    var findQuery by mutableStateOf("")
    var findMatchCount by mutableStateOf(0)
    var findActiveIndex by mutableStateOf(0)

    val activeTab: TabModel? get() = tabs.getOrNull(activeTabIndex)

    fun newTab(initialUrl: String? = null) {
        tabs.add(TabModel(id = nextTabId++, initialTitle = "New Tab", initialUrl = initialUrl ?: ""))
        activeTabIndex = tabs.lastIndex
    }

    fun closeTab(index: Int) {
        if (tabs.size <= 1) return
        tabs.removeAt(index)
        if (activeTabIndex >= tabs.size) activeTabIndex = tabs.lastIndex
    }

    fun selectTab(index: Int) {
        if (index in tabs.indices) activeTabIndex = index
    }

    fun recordVisit(url: String) {
        recentUrls.remove(url)
        recentUrls.add(0, url)
        while (recentUrls.size > 30) recentUrls.removeAt(recentUrls.lastIndex)
    }

    fun computeAutocomplete(prefix: String) {
        if (prefix.isBlank()) { autocompleteResults = emptyList(); return }
        val lower = prefix.lowercase()
        autocompleteResults = recentUrls
            .filter { it.lowercase().contains(lower) }
            .take(8)
    }

    fun toggleBookmark(url: String, title: String) {
        val existing = bookmarks.indexOfFirst { it.url == url }
        if (existing >= 0) bookmarks.removeAt(existing)
        else bookmarks.add(0, BookmarkRow(url = url, title = title.ifBlank { url }))
    }

    fun isBookmarked(url: String): Boolean = bookmarks.any { it.url == url }

    private var nextTabId: Int = 1
}

class TabModel(
    val id: Int,
    initialTitle: String = "New Tab",
    initialUrl: String = "",
) {
    var title by mutableStateOf(initialTitle)
    var url by mutableStateOf(initialUrl)
    var canGoBack by mutableStateOf(false)
    var canGoForward by mutableStateOf(false)
    /** WebView host reference. Bound when the AndroidView factory runs.
     *  Lives in non-Compose state because WebView is mutable Android UI. */
    var webView: WPEView? = null
}

data class BookmarkRow(val url: String, val title: String)

@Composable
fun rememberBrowserState(): BrowserState = remember {
    BrowserState().also { state ->
        val launch = System.getenv("WEBKITIUM_LAUNCH_URL")?.trim()?.takeIf { it.isNotEmpty() }
        state.newTab(launch)
        state.urlInput = launch.orEmpty()
    }
}
