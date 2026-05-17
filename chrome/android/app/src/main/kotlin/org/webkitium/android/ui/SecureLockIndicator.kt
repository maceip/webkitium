package org.webkitium.android.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun SecureLockIndicator(isSecure: Boolean) {
    AnimatedVisibility(
        visible = isSecure,
        enter = fadeIn(animationSpec = tween(250)),
        exit = fadeOut(animationSpec = tween(250))
    ) {
        val glow = Color(0xFF3B82F6)
        Icon(
            imageVector = Icons.Filled.Lock,
            contentDescription = "Secure connection",
            tint = glow,
            modifier = Modifier
                .size(14.dp)
                .drawBehind {
                    drawCircle(
                        color = glow.copy(alpha = 0.55f),
                        radius = size.minDimension * 0.9f,
                        blendMode = BlendMode.Plus
                    )
                    drawCircle(
                        color = glow.copy(alpha = 0.35f),
                        radius = size.minDimension * 1.3f,
                        blendMode = BlendMode.Plus
                    )
                }
        )
    }
}
