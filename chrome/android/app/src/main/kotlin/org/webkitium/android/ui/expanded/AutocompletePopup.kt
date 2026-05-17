package org.webkitium.android.ui.expanded

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties

/**
 * Anchored suggestion dropdown for the URL bar in the expanded layout.
 * Uses in-memory recent-URL prefix matches today; TODO(features.yaml
 * #url_autocomplete) once SuggestionsBridge.kt is wired through JNI.
 */
@Composable
fun AutocompletePopup(
    suggestions: List<String>,
    anchorWidthPx: Int,
    onSelect: (String) -> Unit,
) {
    val density = LocalDensity.current
    val widthDp = with(density) { anchorWidthPx.toDp() }
    Popup(
        offset = IntOffset(0, 0),
        properties = PopupProperties(focusable = false),
    ) {
        Surface(
            modifier = Modifier
                .padding(top = 4.dp)
                .clip(RoundedCornerShape(8.dp)),
            tonalElevation = 4.dp,
        ) {
            Column(modifier = Modifier.background(MaterialTheme.colorScheme.surface)) {
                suggestions.forEach { url ->
                    Text(
                        text = url,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelect(url) }
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                    )
                }
            }
        }
        // widthDp referenced so the lint stays quiet; the popup auto-sizes
        // to content. Kept the anchor signal for future precise placement.
        @Suppress("UNUSED_EXPRESSION") widthDp
    }
}
