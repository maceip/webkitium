package org.webkitium.android.ui

import android.annotation.SuppressLint
import android.content.Context
import org.wpewebkit.wpeview.WPEView
import org.wpewebkit.wpeview.WPEViewClient

/**
 * Pinned WPE WebKit view from the engine build (`wpeview-*.aar`), not
 * `android.webkit.WebView` (Chromium).
 */
@SuppressLint("SetJavaScriptEnabled")
fun createWpeEngineView(
    context: Context,
    onPageStarted: (WPEView, String) -> Unit,
    onPageFinished: (WPEView, String) -> Unit,
): WPEView {
    return WPEView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        setWPEViewClient(object : WPEViewClient() {
            override fun onPageStarted(view: WPEView, url: String) {
                onPageStarted(view, url)
            }

            override fun onPageFinished(view: WPEView, url: String) {
                onPageFinished(view, url)
            }
        })
    }
}

/** In-page find via DOM API until WPE exposes dedicated find hooks. */
fun WPEView.findAllAsync(query: String) {
    if (query.isEmpty()) return
    val escaped = query.replace("\\", "\\\\").replace("'", "\\'")
    evaluateJavascript("window.find('$escaped', false, false, true);", null)
}

fun WPEView.findNext(forward: Boolean) {
    evaluateJavascript("window.find('', false, false, ${if (forward) "true" else "false"});", null)
}

fun WPEView.clearMatches() {
    evaluateJavascript("window.getSelection()?.removeAllRanges();", null)
}
