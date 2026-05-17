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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import org.webkitium.android.ffi.UrlBridge

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun BrowserScreen() {
    // urlInput is the user-editable field; pageUrl mirrors the actual page.
    // Keeping them split so that page-load events don't clobber a user that's
    // mid-typing in the URL bar.
    var urlInput by remember { mutableStateOf("") }
    var webView by remember { mutableStateOf<WebView?>(null) }
    var canGoBack by remember { mutableStateOf(false) }
    var isUserTyping by remember { mutableStateOf(false) }

    // System back: pop WebView history while we have any; otherwise fall through
    // to the default disposition (finish the activity). Chromium's Android shell
    // uses the same pattern.
    BackHandler(enabled = canGoBack) {
        webView?.goBack()
    }

    Scaffold(
        bottomBar = {
            BottomUrlBar(
                url = urlInput,
                onUrlChange = { urlInput = it },
                onSubmit = {
                    val result = UrlBridge.normalize(urlInput) ?: return@BottomUrlBar
                    webView?.loadUrl(result.url)
                },
                onBack = { if (canGoBack) webView?.goBack() },
                canGoBack = canGoBack,
                onMore = { /* TODO: features.yaml#more_menu */ },
                onFocusChange = { isUserTyping = it }
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
                        // Privacy + safety hardening. Mirrors Chromium's
                        // Android-shell WebSettings defaults.
                        mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                        allowFileAccess = false
                        allowContentAccess = false
                        safeBrowsingEnabled = true
                    }
                    webViewClient = object : WebViewClient() {
                        override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                            if (!isUserTyping) urlInput = url
                            canGoBack = view.canGoBack()
                        }
                        override fun onPageFinished(view: WebView, url: String) {
                            if (!isUserTyping) urlInput = url
                            canGoBack = view.canGoBack()
                        }
                        // Keep http/https navigations in-app; defer non-web
                        // schemes (mailto:, tel:, intent:, market:) to the
                        // system so the OS chooser handles them.
                        override fun shouldOverrideUrlLoading(
                            view: WebView,
                            request: WebResourceRequest
                        ): Boolean = when (request.url.scheme?.lowercase()) {
                            "http", "https" -> false
                            else            -> true
                        }
                    }
                    webView = this
                }
            }
        )
    }
}
