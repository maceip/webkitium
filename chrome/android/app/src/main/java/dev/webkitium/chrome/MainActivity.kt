package dev.webkitium.chrome

import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.adaptive.ExperimentalMaterial3AdaptiveApi
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.compose.material3.adaptive.layout.calculatePaneScaffoldDirective
import androidx.compose.material3.adaptive.navigation.BackNavigationBehavior
import androidx.compose.material3.adaptive.navigation3.SupportingPaneSceneStrategy
import androidx.compose.material3.adaptive.navigation3.rememberSupportingPaneSceneStrategy
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation3.runtime.NavKey
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberNavBackStack
import androidx.navigation3.ui.NavDisplay
import java.util.UUID
import kotlinx.serialization.Serializable

data class BrowserTab(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val url: String,
)

@Serializable
private data object BrowserPage : NavKey

@Serializable
private data object TabOverview : NavKey

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

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterial3AdaptiveApi::class)
@Composable
fun BrowserChromeApp() {
    val tabs = remember {
        mutableStateListOf(BrowserTab(title = "Start", url = "https://example.com"))
    }
    var selectedTabId by remember { mutableStateOf(tabs.first().id) }
    var addressText by remember { mutableStateOf(tabs.first().url) }
    val backStack = rememberNavBackStack(BrowserPage)
    val windowAdaptiveInfo = currentWindowAdaptiveInfo()
    val directive = remember(windowAdaptiveInfo) {
        calculatePaneScaffoldDirective(windowAdaptiveInfo)
            .copy(horizontalPartitionSpacerSize = 0.dp, verticalPartitionSpacerSize = 0.dp)
    }
    val supportingPaneStrategy = rememberSupportingPaneSceneStrategy<NavKey>(
        backNavigationBehavior = BackNavigationBehavior.PopUntilCurrentDestinationChange,
        directive = directive,
    )

    fun showTabs() {
        if (!backStack.contains(TabOverview)) {
            backStack.add(TabOverview)
        }
    }

    fun addTab() {
        val tab = BrowserTab(title = "New Tab", url = "https://example.com")
        tabs.add(tab)
        selectedTabId = tab.id
        addressText = tab.url
        showTabs()
    }

    fun selectTab(tab: BrowserTab) {
        selectedTabId = tab.id
        addressText = tab.url
    }

    fun closeTab(tab: BrowserTab) {
        if (tabs.size == 1) {
            return
        }

        val index = tabs.indexOf(tab)
        tabs.remove(tab)
        if (selectedTabId == tab.id) {
            val fallback = tabs.getOrNull(index.coerceAtMost(tabs.lastIndex)) ?: tabs.last()
            selectTab(fallback)
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
                Button(onClick = ::showTabs) {
                    Text("Tabs")
                }
                Button(onClick = ::addTab) {
                    Text("New Tab")
                }
            }

            NavDisplay(
                backStack = backStack,
                onBack = { backStack.removeLastOrNull() },
                sceneStrategies = listOf(supportingPaneStrategy),
                entryProvider = entryProvider {
                    entry<BrowserPage>(
                        metadata = SupportingPaneSceneStrategy.mainPane()
                    ) {
                        val selectedTab = tabs.first { it.id == selectedTabId }
                        AndroidWebPage(
                            url = selectedTab.url,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    entry<TabOverview>(
                        metadata = SupportingPaneSceneStrategy.supportingPane()
                    ) {
                        TabOverviewPane(
                            tabs = tabs,
                            selectedTabId = selectedTabId,
                            onSelectTab = ::selectTab,
                            onNewTab = ::addTab,
                            onCloseTab = ::closeTab,
                        )
                    }
                }
            )
        }
    }
}

@Composable
private fun TabOverviewPane(
    tabs: List<BrowserTab>,
    selectedTabId: String,
    onSelectTab: (BrowserTab) -> Unit,
    onNewTab: () -> Unit,
    onCloseTab: (BrowserTab) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("Tabs", style = MaterialTheme.typography.titleMedium)
            Button(onClick = onNewTab) {
                Text("New Tab")
            }
        }

        Row(
            modifier = Modifier
                .horizontalScroll(rememberScrollState())
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            tabs.forEach { tab ->
                Column(
                    modifier = Modifier.padding(vertical = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Button(onClick = { onSelectTab(tab) }) {
                        Text(if (tab.id == selectedTabId) "${tab.title} *" else tab.title)
                    }
                    Button(
                        enabled = tabs.size > 1,
                        onClick = { onCloseTab(tab) },
                    ) {
                        Text("Close")
                    }
                }
            }
        }

        HorizontalDivider()
        Text(
            "On foldables and large screens this pane can stay beside the page. On compact screens it behaves like a tab overview destination.",
            style = MaterialTheme.typography.bodyMedium,
        )
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
