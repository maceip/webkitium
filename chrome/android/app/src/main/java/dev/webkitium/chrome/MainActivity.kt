package dev.webkitium.chrome

import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.compose.PredictiveBackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import java.util.UUID
import kotlinx.coroutines.CancellationException

data class BrowserTab(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val url: String,
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                BrowserChromeApp()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BrowserChromeApp() {
    val tabs = remember {
        mutableStateListOf(BrowserTab(title = "Start", url = "https://example.com"))
    }
    var selectedTabId by remember { mutableStateOf(tabs.first().id) }
    var addressText by remember { mutableStateOf(tabs.first().url) }

    PredictiveBackHandler(enabled = tabs.size > 1) { progress ->
        try {
            progress.collect { }
            val selectedIndex = tabs.indexOfFirst { it.id == selectedTabId }
            if (selectedIndex >= 0) {
                tabs.removeAt(selectedIndex)
                selectedTabId = tabs.last().id
                addressText = tabs.last().url
            }
        } catch (_: CancellationException) {
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Webkitium") })
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp)
            ) {
                Button(onClick = {}) {
                    Text("Back")
                }
                Button(onClick = {}) {
                    Text("Reload")
                }
                OutlinedTextField(
                    value = addressText,
                    onValueChange = { addressText = it },
                    singleLine = true,
                    modifier = Modifier
                        .padding(horizontal = 8.dp)
                        .weight(1f),
                    label = { Text("Search or enter website name") },
                )
                Button(onClick = {
                    val tab = BrowserTab(title = "New Tab", url = "https://example.com")
                    tabs.add(tab)
                    selectedTabId = tab.id
                    addressText = tab.url
                }) {
                    Text("New Tab")
                }
            }

            Row(
                modifier = Modifier
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 8.dp)
            ) {
                tabs.forEach { tab ->
                    Button(
                        modifier = Modifier.padding(end = 6.dp),
                        onClick = {
                            selectedTabId = tab.id
                            addressText = tab.url
                        }
                    ) {
                        Text(tab.title)
                    }
                }
            }

            val selectedTab = tabs.first { it.id == selectedTabId }
            AndroidWebPage(
                url = selectedTab.url,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}

@Composable
fun AndroidWebPage(url: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    AndroidView(
        modifier = modifier,
        factory = {
            WebView(context).apply {
                webViewClient = WebViewClient()
                settings.javaScriptEnabled = true
                loadUrl(url)
            }
        },
        update = { webView ->
            if (webView.url != url) {
                webView.loadUrl(url)
            }
        }
    )
}
