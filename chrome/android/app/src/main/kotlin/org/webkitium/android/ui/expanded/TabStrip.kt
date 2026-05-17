package org.webkitium.android.ui.expanded

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import org.webkitium.android.ui.TabModel

/**
 * Tab strip for the expanded layout — LazyRow of tab chips with a
 * close-X per tab and a `+` button at the end.
 */
@Composable
fun TabStrip(
    tabs: List<TabModel>,
    activeIndex: Int,
    onSelect: (Int) -> Unit,
    onClose: (Int) -> Unit,
    onNewTab: () -> Unit,
) {
    Surface(color = MaterialTheme.colorScheme.surfaceContainerLow, tonalElevation = 2.dp) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            LazyRow(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                itemsIndexed(tabs) { idx, tab ->
                    TabChip(
                        title = tab.title.ifBlank { tab.url.ifBlank { "New Tab" } },
                        isActive = idx == activeIndex,
                        onSelect = { onSelect(idx) },
                        onClose = { onClose(idx) },
                    )
                }
            }
            IconButton(onClick = onNewTab) {
                Icon(Icons.Filled.Add, contentDescription = "New tab")
            }
        }
    }
}

@Composable
private fun TabChip(
    title: String,
    isActive: Boolean,
    onSelect: () -> Unit,
    onClose: () -> Unit,
) {
    val bg = if (isActive)
        MaterialTheme.colorScheme.secondaryContainer
    else
        MaterialTheme.colorScheme.surfaceVariant
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .clickable { onSelect() }
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title.take(24),
            style = MaterialTheme.typography.bodyMedium,
        )
        IconButton(
            onClick = onClose,
            modifier = Modifier.size(24.dp).padding(start = 6.dp),
        ) {
            Icon(
                Icons.Filled.Close,
                contentDescription = "Close tab: $title",
                modifier = Modifier.size(16.dp),
            )
        }
    }
}
