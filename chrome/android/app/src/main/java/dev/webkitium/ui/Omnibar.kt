package dev.webkitium.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.outlined.Extension
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.webkitium.theme.LocalSemantic
import dev.webkitium.theme.SemanticToken

/**
 * Omnibar -- Android implementation of design/components/omnibar/SPEC.md.
 *
 * Floating pill anchored by the parent composition (typically at the
 * bottom of the screen on phones, at the top on tablets).  Interaction
 * contract matches Windows and macOS: leading lockmark, editable field
 * with placeholder, trailing reload + extensions + overflow cluster.
 */
@Composable
fun Omnibar(
    modifier: Modifier = Modifier,
    onSubmit: ((String) -> Unit)? = null,
) {
    val semantic = LocalSemantic.current
    val focusRequester = remember { FocusRequester() }

    var text by remember { mutableStateOf("") }
    var focused by remember { mutableStateOf(false) }

    val borderWidth by animateDpAsState(
        targetValue = if (focused) 2.dp else 1.dp,
        label = "omnibar-border",
    )
    val borderColor =
        if (focused) semantic[SemanticToken.BorderFocus]
        else semantic[SemanticToken.BorderSubtle]

    val shape = RoundedCornerShape(28.dp)  // platform-overrides/android.tokens.json

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(semantic[SemanticToken.SurfaceSunken], shape)
            .border(borderWidth, borderColor, shape)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Lock,
            contentDescription = null,
            tint = semantic[SemanticToken.AccentFill],
        )

        BasicTextField(
            value = text,
            onValueChange = { text = it },
            modifier = Modifier
                .weight(1f)
                .focusRequester(focusRequester)
                .onFocusChanged { focused = it.isFocused },
            textStyle = TextStyle(
                color = semantic[SemanticToken.TextPrimary],
                fontSize = 14.sp,
            ),
            cursorBrush = androidx.compose.ui.graphics.SolidColor(
                semantic[SemanticToken.AccentFill]
            ),
            singleLine = true,
            keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                imeAction = androidx.compose.ui.text.input.ImeAction.Go
            ),
            keyboardActions = androidx.compose.foundation.text.KeyboardActions(
                onGo = {
                    if (text.isNotBlank()) {
                        onSubmit?.invoke(text)
                    }
                }
            ),
            decorationBox = { innerTextField ->
                if (text.isEmpty()) {
                    Text(
                        text = "Search or enter address",
                        color = semantic[SemanticToken.TextTertiary],
                        fontSize = 14.sp,
                    )
                }
                innerTextField()
            },
        )

        OmnibarAction(
            icon = Icons.Filled.Refresh,
            tint = semantic[SemanticToken.TextTertiary],
            onClick = { /* stub -- reload */ },
        )
        OmnibarAction(
            icon = Icons.Outlined.Extension,
            tint = semantic[SemanticToken.TextTertiary],
            onClick = { /* stub -- extensions menu */ },
        )
        OmnibarAction(
            icon = Icons.Filled.MoreVert,
            tint = semantic[SemanticToken.TextTertiary],
            onClick = { /* stub -- overflow */ },
        )
    }
}

@Composable
private fun OmnibarAction(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: androidx.compose.ui.graphics.Color,
    onClick: () -> Unit,
) {
    IconButton(onClick = onClick) {
        Icon(imageVector = icon, contentDescription = null, tint = tint)
    }
}
