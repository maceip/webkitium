package org.webkitium.android.ui.expanded

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.webkitium.android.ui.BookmarkRow

/**
 * Supporting pane showing the user's bookmarks. Tap a row to navigate
 * the active tab. Currently sources from in-memory [BookmarkRow] list
 * on [BrowserState]; TODO(features.yaml#bookmarks_persist) once the
 * Android JNI bridge for wk_suggestions_bookmarks_flat is in place.
 */
@Composable
fun BookmarksPane(
    bookmarks: List<BookmarkRow>,
    onNavigate: (String) -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxSize(),
        tonalElevation = 1.dp,
    ) {
        Column {
            Text(
                text = "Bookmarks",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(16.dp),
            )
            HorizontalDivider()
            if (bookmarks.isEmpty()) {
                Text(
                    text = "No bookmarks yet. Tap the star in the toolbar to bookmark the current page.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(16.dp),
                )
            } else {
                LazyColumn(modifier = Modifier.fillMaxWidth()) {
                    items(bookmarks, key = { it.url }) { row ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onNavigate(row.url) }
                                .padding(horizontal = 16.dp, vertical = 8.dp),
                        ) {
                            Text(row.title, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                row.url,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}
