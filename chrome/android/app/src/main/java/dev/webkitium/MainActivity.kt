package dev.webkitium

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.net.http.SslError
import android.os.Bundle
import android.print.PrintAttributes
import android.print.PrintManager
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import android.webkit.SslErrorHandler
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Print
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.ZoomIn
import androidx.compose.material.icons.filled.ZoomOut
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import dev.webkitium.services.BrowserServices
import dev.webkitium.theme.LocalPaletteProvider
import dev.webkitium.theme.LocalSemantic
import dev.webkitium.theme.SemanticToken
import dev.webkitium.theme.WebkitiumTheme
import dev.webkitium.ui.Omnibar

class MainActivity : ComponentActivity() {
    private var services: BrowserServices? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        services = BrowserServices.create()
        enableEdgeToEdge()
        setContent {
            WebkitiumTheme {
                RootScreen()
            }
        }
    }

    override fun onDestroy() {
        services?.dispose()
        services = null
        super.onDestroy()
    }
}

data class HistoryEntry(val url: String, val title: String)
data class BookmarkEntry(val url: String, val title: String)

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun RootScreen() {
    val semantic = LocalSemantic.current
    val provider = LocalPaletteProvider.current
    val context = LocalContext.current

    var webView by remember { mutableStateOf<WebView?>(null) }
    var currentUrl by remember { mutableStateOf("https://example.com/") }
    var currentTitle by remember { mutableStateOf("New Tab") }
    var canGoBack by remember { mutableStateOf(false) }
    var canGoForward by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }
    var loadProgress by remember { mutableFloatStateOf(0f) }
    var showFindBar by remember { mutableStateOf(false) }
    var findQuery by remember { mutableStateOf("") }
    var showHistory by remember { mutableStateOf(false) }
    var showBookmarks by remember { mutableStateOf(false) }
    val history = remember { mutableStateListOf<HistoryEntry>() }
    val bookmarks = remember { mutableStateListOf<BookmarkEntry>() }

    val devCycleModifier = Modifier.pointerInput(provider) {
        detectTapGestures(onLongPress = { provider?.cycleDevSeed() })
    }

    BackHandler(enabled = canGoBack) {
        webView?.goBack()
    }

    Surface(
        modifier = Modifier
            .fillMaxSize()
            .background(semantic[SemanticToken.SurfaceCanvas])
            .then(devCycleModifier),
        color = semantic[SemanticToken.SurfaceCanvas],
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
        ) {
            // Progress bar
            if (isLoading) {
                LinearProgressIndicator(
                    progress = { loadProgress },
                    modifier = Modifier.fillMaxWidth().height(2.dp),
                    color = semantic[SemanticToken.AccentFill],
                )
            }

            // Nav toolbar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(0.dp),
            ) {
                IconButton(onClick = { webView?.goBack() }, enabled = canGoBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back",
                        tint = if (canGoBack) semantic[SemanticToken.TextPrimary]
                               else semantic[SemanticToken.TextTertiary])
                }
                IconButton(onClick = { webView?.goForward() }, enabled = canGoForward) {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, "Forward",
                        tint = if (canGoForward) semantic[SemanticToken.TextPrimary]
                               else semantic[SemanticToken.TextTertiary])
                }
                IconButton(onClick = { webView?.reload() }) {
                    Icon(Icons.Filled.Refresh, "Reload",
                        tint = semantic[SemanticToken.TextSecondary])
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { showFindBar = !showFindBar }) {
                    Icon(Icons.Filled.Search, "Find",
                        tint = semantic[SemanticToken.TextSecondary])
                }
                IconButton(onClick = {
                    bookmarks.add(BookmarkEntry(currentUrl, currentTitle))
                    Toast.makeText(context, "Bookmarked", Toast.LENGTH_SHORT).show()
                }) {
                    Icon(Icons.Filled.Bookmark, "Bookmark",
                        tint = semantic[SemanticToken.TextSecondary])
                }
                IconButton(onClick = { showHistory = !showHistory; showBookmarks = false }) {
                    Icon(Icons.Filled.History, "History",
                        tint = semantic[SemanticToken.TextSecondary])
                }
                IconButton(onClick = {
                    val wv = webView ?: return@IconButton
                    val pm = context.getSystemService(PrintManager::class.java)
                    val adapter = wv.createPrintDocumentAdapter(currentTitle)
                    pm.print(currentTitle, adapter, PrintAttributes.Builder().build())
                }) {
                    Icon(Icons.Filled.Print, "Print",
                        tint = semantic[SemanticToken.TextSecondary])
                }
                IconButton(onClick = {
                    val wv = webView ?: return@IconButton
                    val z = (wv.settings.textZoom + 10).coerceAtMost(300)
                    wv.settings.textZoom = z
                }) {
                    Icon(Icons.Filled.ZoomIn, "Zoom In",
                        tint = semantic[SemanticToken.TextSecondary])
                }
                IconButton(onClick = {
                    val wv = webView ?: return@IconButton
                    val z = (wv.settings.textZoom - 10).coerceAtLeast(25)
                    wv.settings.textZoom = z
                }) {
                    Icon(Icons.Filled.ZoomOut, "Zoom Out",
                        tint = semantic[SemanticToken.TextSecondary])
                }
            }

            // Find bar
            AnimatedVisibility(
                visible = showFindBar,
                enter = slideInVertically(),
                exit = slideOutVertically(),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 4.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(semantic[SemanticToken.SurfaceSunken])
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    BasicTextField(
                        value = findQuery,
                        onValueChange = { findQuery = it },
                        modifier = Modifier.weight(1f),
                        textStyle = TextStyle(
                            color = semantic[SemanticToken.TextPrimary],
                            fontSize = 14.sp
                        ),
                        singleLine = true,
                        decorationBox = { inner ->
                            if (findQuery.isEmpty()) {
                                Text("Find in page",
                                    color = semantic[SemanticToken.TextTertiary],
                                    fontSize = 14.sp)
                            }
                            inner()
                        }
                    )
                    Spacer(Modifier.width(8.dp))
                    IconButton(onClick = {
                        webView?.findAllAsync(findQuery)
                    }, modifier = Modifier.size(32.dp)) {
                        Icon(Icons.Filled.Search, "Find",
                            tint = semantic[SemanticToken.TextSecondary],
                            modifier = Modifier.size(18.dp))
                    }
                    IconButton(onClick = {
                        showFindBar = false
                        findQuery = ""
                        webView?.clearMatches()
                    }, modifier = Modifier.size(32.dp)) {
                        Icon(Icons.Filled.Close, "Close",
                            tint = semantic[SemanticToken.TextSecondary],
                            modifier = Modifier.size(18.dp))
                    }
                }
            }

            // History panel
            if (showHistory) {
                HistoryPanel(history, semantic, onItemClick = { entry ->
                    webView?.loadUrl(entry.url)
                    showHistory = false
                })
            }

            // Bookmarks panel
            if (showBookmarks) {
                BookmarksPanel(bookmarks, semantic, onItemClick = { entry ->
                    webView?.loadUrl(entry.url)
                    showBookmarks = false
                }, onRemove = { bookmarks.remove(it) })
            }

            // WebView
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .weight(1f),
            ) {
                AndroidView(
                    factory = { ctx ->
                        WebView(ctx).apply {
                            layoutParams = ViewGroup.LayoutParams(
                                ViewGroup.LayoutParams.MATCH_PARENT,
                                ViewGroup.LayoutParams.MATCH_PARENT
                            )
                            settings.javaScriptEnabled = true
                            settings.domStorageEnabled = true
                            settings.databaseEnabled = true
                            settings.cacheMode = WebSettings.LOAD_DEFAULT
                            settings.setSupportZoom(true)
                            settings.builtInZoomControls = true
                            settings.displayZoomControls = false
                            settings.setSupportMultipleWindows(false)
                            settings.allowContentAccess = true
                            settings.loadWithOverviewMode = true
                            settings.useWideViewPort = true

                            CookieManager.getInstance().setAcceptCookie(true)
                            CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)

                            webViewClient = object : WebViewClient() {
                                override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                                    isLoading = true
                                    currentUrl = url
                                    canGoBack = view.canGoBack()
                                    canGoForward = view.canGoForward()
                                }

                                override fun onPageFinished(view: WebView, url: String) {
                                    isLoading = false
                                    currentUrl = url
                                    currentTitle = view.title ?: url
                                    canGoBack = view.canGoBack()
                                    canGoForward = view.canGoForward()
                                    history.add(0, HistoryEntry(url, view.title ?: url))
                                    if (history.size > 500) history.removeLast()
                                }

                                override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                                    if (request.isForMainFrame) {
                                        loadErrorPage(view, request.url.toString(), error.description.toString())
                                    }
                                }

                                @Suppress("DEPRECATION")
                                override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
                                    handler.cancel()
                                    loadErrorPage(view, error.url, "SSL certificate error")
                                }
                            }

                            webChromeClient = object : WebChromeClient() {
                                override fun onProgressChanged(view: WebView, newProgress: Int) {
                                    loadProgress = newProgress / 100f
                                }

                                override fun onReceivedTitle(view: WebView, title: String?) {
                                    currentTitle = title ?: ""
                                }

                                override fun onGeolocationPermissionsShowPrompt(
                                    origin: String,
                                    callback: GeolocationPermissions.Callback
                                ) {
                                    callback.invoke(origin, false, false)
                                    Toast.makeText(ctx, "Location access denied for $origin", Toast.LENGTH_SHORT).show()
                                }

                                override fun onPermissionRequest(request: PermissionRequest) {
                                    request.deny()
                                    Toast.makeText(ctx, "Permission denied: ${request.resources.joinToString()}", Toast.LENGTH_SHORT).show()
                                }
                            }

                            setDownloadListener(DownloadListener { url, _, _, mimetype, _ ->
                                Toast.makeText(ctx, "Download: $url ($mimetype)", Toast.LENGTH_LONG).show()
                            })

                            setOnLongClickListener {
                                val hr = hitTestResult
                                if (hr.type != WebView.HitTestResult.UNKNOWN_TYPE) {
                                    Toast.makeText(ctx, hr.extra ?: "Context action", Toast.LENGTH_SHORT).show()
                                }
                                false
                            }

                            loadUrl("https://example.com/")
                            webView = this
                        }
                    },
                    modifier = Modifier.fillMaxSize(),
                )
            }

            // Omnibar at bottom
            Omnibar(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                onSubmit = { text ->
                    val url = normalizeUrl(text)
                    webView?.loadUrl(url)
                }
            )
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            webView?.destroy()
        }
    }
}

@Composable
private fun HistoryPanel(
    history: List<HistoryEntry>,
    semantic: dev.webkitium.theme.SemanticPalette,
    onItemClick: (HistoryEntry) -> Unit,
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .padding(horizontal = 12.dp)
    ) {
        items(history.take(50)) { entry ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onItemClick(entry) }
                    .padding(vertical = 4.dp)
            ) {
                Text(entry.title, fontSize = 13.sp, fontWeight = FontWeight.Medium,
                    color = semantic[SemanticToken.TextPrimary], maxLines = 1)
                Text(entry.url, fontSize = 11.sp,
                    color = semantic[SemanticToken.TextTertiary], maxLines = 1)
            }
        }
    }
}

@Composable
private fun BookmarksPanel(
    bookmarks: List<BookmarkEntry>,
    semantic: dev.webkitium.theme.SemanticPalette,
    onItemClick: (BookmarkEntry) -> Unit,
    onRemove: (BookmarkEntry) -> Unit,
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .padding(horizontal = 12.dp)
    ) {
        items(bookmarks) { entry ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onItemClick(entry) }
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(entry.title, fontSize = 13.sp, fontWeight = FontWeight.Medium,
                        color = semantic[SemanticToken.TextPrimary], maxLines = 1)
                    Text(entry.url, fontSize = 11.sp,
                        color = semantic[SemanticToken.TextTertiary], maxLines = 1)
                }
                IconButton(onClick = { onRemove(entry) }, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Filled.Close, "Remove",
                        tint = semantic[SemanticToken.TextTertiary],
                        modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}

private fun loadErrorPage(webView: WebView, failedUrl: String, message: String) {
    val html = """
        <!DOCTYPE html><html><head><meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <style>
          body { font-family: system-ui, sans-serif; display: flex;
                 flex-direction: column; align-items: center; justify-content: center;
                 height: 100vh; margin: 0; background: #1a1a2e; color: #e0e0e0; }
          h1 { font-size: 20px; margin-bottom: 8px; color: #ff6b6b; }
          p { font-size: 14px; color: #a0a0a0; max-width: 90%; text-align: center; }
          code { background: #2a2a3e; padding: 2px 6px; border-radius: 4px;
                 word-break: break-all; }
          button { margin-top: 16px; padding: 10px 28px; border: none;
                   border-radius: 8px; background: #4a9eff; color: #fff;
                   font-size: 14px; }
        </style></head><body>
        <h1>This page isn't working</h1>
        <p><code>${failedUrl.htmlEscape()}</code></p>
        <p>${message.htmlEscape()}</p>
        <button onclick="history.back()">Go back</button>
        </body></html>
    """.trimIndent()
    webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", failedUrl)
}

private fun String.htmlEscape(): String =
    this.replace("&", "&amp;").replace("<", "&lt;")
        .replace(">", "&gt;").replace("\"", "&quot;")

private fun normalizeUrl(text: String): String {
    val trimmed = text.trim()
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://") ||
        trimmed.startsWith("file://"))
        return trimmed
    if (trimmed.contains(".") && !trimmed.contains(" "))
        return "https://$trimmed"
    return "https://duckduckgo.com/?q=${java.net.URLEncoder.encode(trimmed, "UTF-8")}"
}
