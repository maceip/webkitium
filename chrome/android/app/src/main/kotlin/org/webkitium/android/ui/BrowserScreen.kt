package org.webkitium.android.ui

import androidx.activity.ComponentActivity
import androidx.compose.material3.windowsizeclass.ExperimentalMaterial3WindowSizeClassApi
import androidx.compose.material3.windowsizeclass.WindowWidthSizeClass
import androidx.compose.material3.windowsizeclass.calculateWindowSizeClass
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

/**
 * Root browser screen. Computes the current `WindowSizeClass` and
 * branches between a compact (phone portrait, foldable folded) layout
 * and a medium / expanded (foldable unfolded, tablet, landscape) layout
 * that mirrors the desktop chrome.
 *
 * Both layouts share a single `BrowserState` so tabs, URL, autocomplete,
 * bookmarks, and find-state survive a layout-class transition (e.g.
 * unfolding a foldable).
 */
@OptIn(ExperimentalMaterial3WindowSizeClassApi::class)
@Composable
fun BrowserScreen() {
    val activity = LocalContext.current as ComponentActivity
    val sizeClass = calculateWindowSizeClass(activity)
    val state = rememberBrowserState()

    when (sizeClass.widthSizeClass) {
        WindowWidthSizeClass.Compact -> BrowserScreenCompact(state)
        else                         -> BrowserScreenExpanded(state)
    }
}
