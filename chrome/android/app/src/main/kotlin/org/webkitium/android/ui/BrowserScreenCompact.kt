package org.webkitium.android.ui

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import org.webkitium.android.ffi.UrlBridge

/**
 * Compact-width browser layout. Phone-portrait / foldable-folded. Single
 * WebView with a bottom URL bar — unchanged from the original single-tab
 * mobile chrome (the directive says: "On compact width: keep the existing
 * mobile UI verbatim").
 *
 * Reads from the shared [BrowserState] so a layout-class transition into
 * the expanded layout preserves the current URL.
 */
@SuppressLint("SetJavaScriptEnabled")
@Composable
fun BrowserScreenCompact(state: BrowserState) {
    val active = state.activeTab ?: return

    BackHandler(enabled = active.canGoBack) {
        active.webView?.goBack()
    }

    Scaffold(
        bottomBar = {
            BottomUrlBar(
                url = state.urlInput,
                onUrlChange = { state.urlInput = it },
                onSubmit = {
                    val result = UrlBridge.normalize(state.urlInput) ?: return@BottomUrlBar
                    active.webView?.loadUrl(result.url)
                },
                onBack = { if (active.canGoBack) active.webView?.goBack() },
                canGoBack = active.canGoBack,
                onMore = { /* TODO: features.yaml#more_menu */ },
                onFocusChange = { state.isUrlFocused = it }
            )
        }
    ) { padding ->
        AndroidView(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            factory = { ctx ->
                WebView(ctx).apply {
                    settings.apply {
                        javaScriptEnabled = true
                        domStorageEnabled = true
                        mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                        allowFileAccess = false
                        allowContentAccess = false
                        safeBrowsingEnabled = true
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
    }
}
