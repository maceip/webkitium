package org.webkitium.android.ui

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.zIndex
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.adaptive.ExperimentalMaterial3AdaptiveApi
import androidx.compose.material3.adaptive.layout.AnimatedPane
import androidx.compose.material3.adaptive.layout.SupportingPaneScaffold
import androidx.compose.material3.adaptive.navigation.rememberSupportingPaneScaffoldNavigator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import org.webkitium.android.ffi.UrlBridge
import org.webkitium.android.ui.expanded.AutocompletePopup
import org.webkitium.android.ui.expanded.BookmarksPane
import org.webkitium.android.ui.expanded.FindBar
import org.webkitium.android.ui.expanded.TabStrip
import org.webkitium.android.ui.expanded.TopChromeBar

/**
 * Medium / expanded layout — foldable unfolded, tablet, landscape phone.
 * Desktop-style chrome that mirrors the macOS / Linux / Windows shells:
 *
 *   ┌────────────────────────────────────────────────────────┬─────────┐
 *   │ TopChromeBar  (back / forward / URL / star / ⋯ / find) │         │
 *   ├────────────────────────────────────────────────────────┤  Book-  │
 *   │ TabStrip      (LazyRow of tab chips with close-X)      │  marks  │
 *   ├────────────────────────────────────────────────────────┤  pane   │
 *   │ FindBar       (Surface overlay, visible when open)     │         │
 *   ├────────────────────────────────────────────────────────┤         │
 *   │                                                        │         │
 *   │  Active tab's WebView                                  │         │
 *   │                                                        │         │
 *   └────────────────────────────────────────────────────────┴─────────┘
 *
 * Uses Material 3 Adaptive's [SupportingPaneScaffold] with the bookmarks
 * pane as the supporting pane.
 */
@SuppressLint("SetJavaScriptEnabled")
@OptIn(ExperimentalMaterial3AdaptiveApi::class)
@Composable
fun BrowserScreenExpanded(state: BrowserState) {
    val navigator = rememberSupportingPaneScaffoldNavigator<Nothing>()

    SupportingPaneScaffold(
        directive = navigator.scaffoldDirective,
        value = navigator.scaffoldValue,
        mainPane = {
            AnimatedPane {
                MainPane(state)
            }
        },
        supportingPane = {
            AnimatedPane {
                BookmarksPane(
                    bookmarks = state.bookmarks,
                    onNavigate = { url ->
                        state.activeTab?.webView?.loadUrl(url)
                    }
                )
            }
        }
    )
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun MainPane(state: BrowserState) {
    val active = state.activeTab ?: return
    var anchorWidthPx by remember { mutableStateOf(0) }

    Column(modifier = Modifier.fillMaxSize().statusBarsPadding().clipToBounds()) {
        TopChromeBar(
            url = state.urlInput,
            onUrlChange = { value ->
                state.urlInput = value
                state.computeAutocomplete(value)
            },
            onSubmit = {
                val result = UrlBridge.normalize(state.urlInput) ?: return@TopChromeBar
                active.webView?.loadUrl(result.url)
                state.autocompleteResults = emptyList()
            },
            onBack = { if (active.canGoBack) active.webView?.goBack() },
            onForward = { if (active.canGoForward) active.webView?.goForward() },
            canGoBack = active.canGoBack,
            canGoForward = active.canGoForward,
            isBookmarked = state.isBookmarked(active.url),
            onToggleBookmark = { state.toggleBookmark(active.url, active.title) },
            onToggleFind = { state.isFindOpen = !state.isFindOpen },
            onMore = { /* TODO: features.yaml#more_menu */ },
            onFocusChange = { focused ->
                state.isUrlFocused = focused
                if (!focused) state.autocompleteResults = emptyList()
            },
            onMeasured = { px -> anchorWidthPx = px }
        )

        TabStrip(
            tabs = state.tabs,
            activeIndex = state.activeTabIndex,
            onSelect = { state.selectTab(it) },
            onClose = { state.closeTab(it) },
            onNewTab = { state.newTab() }
        )

        if (state.isFindOpen) {
            FindBar(
                query = state.findQuery,
                onQueryChange = { q ->
                    state.findQuery = q
                    active.webView?.findAllAsync(q)
                },
                matchCount = state.findMatchCount,
                activeIndex = state.findActiveIndex,
                onPrev = { active.webView?.findNext(false) },
                onNext = { active.webView?.findNext(true) },
                onClose = {
                    state.isFindOpen = false
                    state.findQuery = ""
                    active.webView?.clearMatches()
                }
            )
        }

        HorizontalDivider()

        Box(modifier = Modifier.fillMaxWidth().weight(1f).clipToBounds()) {
            AndroidView(
                modifier = Modifier.fillMaxSize().zIndex(0f),
                factory = { ctx ->
                    WebView(ctx).apply {
                        // Force a software-managed layer so WebView's
                        // underlying SurfaceView doesn't punch through
                        // sibling Compose UI in AndroidView contexts.
                        setLayerType(View.LAYER_TYPE_HARDWARE, null)
                        settings.apply {
                            javaScriptEnabled = true
                            domStorageEnabled = true
                            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                            allowFileAccess = false
                            allowContentAccess = false
                            safeBrowsingEnabled = true
                        }
                        setFindListener { activeMatchOrdinal, numberOfMatches, _ ->
                            state.findMatchCount = numberOfMatches
                            state.findActiveIndex = activeMatchOrdinal
                        }
                        webViewClient = object : WebViewClient() {
                            override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                                if (!state.isUrlFocused) state.urlInput = url
                                active.url = url
                                active.canGoBack = view.canGoBack()
                                active.canGoForward = view.canGoForward()
                            }
                            override fun onPageFinished(view: WebView, url: String) {
                                if (!state.isUrlFocused) state.urlInput = url
                                active.url = url
                                active.title = view.title ?: url
                                active.canGoBack = view.canGoBack()
                                active.canGoForward = view.canGoForward()
                                state.recordVisit(url)
                            }
                            override fun shouldOverrideUrlLoading(
                                view: WebView,
                                request: WebResourceRequest
                            ): Boolean = when (request.url.scheme?.lowercase()) {
                                "http", "https" -> false
                                else            -> true
                            }
                        }
                        active.webView = this
                    }
                }
            )

            if (state.isUrlFocused && state.autocompleteResults.isNotEmpty()) {
                AutocompletePopup(
                    suggestions = state.autocompleteResults,
                    anchorWidthPx = anchorWidthPx,
                    onSelect = { url ->
                        state.urlInput = url
                        val result = UrlBridge.normalize(url) ?: return@AutocompletePopup
                        active.webView?.loadUrl(result.url)
                        state.autocompleteResults = emptyList()
                    }
                )
            }
        }
    }
}

