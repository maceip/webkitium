package dev.webkitium.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.viewmodel.compose.viewModel

/**
 * Composition-local access to the current semantic palette.
 *
 * Composables read `LocalSemantic.current[SemanticToken.SurfaceChrome]`
 * rather than MaterialTheme.colorScheme when they need a webkitium-
 * specific role that does not map 1:1 onto Material.
 */
val LocalSemantic = compositionLocalOf<SemanticPalette> {
    error("LocalSemantic accessed outside WebkitiumTheme")
}

/**
 * Composition-local access to the palette provider for dev shortcuts
 * (e.g. the three-finger tap that cycles seeds).
 */
val LocalPaletteProvider = staticCompositionLocalOf<PaletteProvider?> { null }

/**
 * Root theme wrapper.  Passes our own [ColorScheme] into [MaterialTheme]
 * -- never [dynamicLightColorScheme].  Material 3 widgets still work
 * because their color roles pull from the scheme we provide.
 *
 * Semantic-to-Material mapping (lossy but consistent):
 *   surface          <- SurfaceChrome
 *   onSurface        <- TextPrimary
 *   surfaceVariant   <- SurfaceSunken
 *   onSurfaceVariant <- TextSecondary
 *   primary          <- AccentFill
 *   onPrimary        <- TextOnBrand
 *   primaryContainer <- AccentFillSubtle
 *   background       <- SurfaceCanvas
 *   onBackground     <- TextPrimary
 *   outline          <- BorderDefault
 *   outlineVariant   <- BorderSubtle
 *   error            <- TextDanger
 */
@Composable
fun WebkitiumTheme(
    dark: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val provider: PaletteProvider = viewModel()
    val snapshot by provider.state.collectAsState()

    val semantic = if (dark) snapshot.dark else snapshot.light
    val materialScheme = semantic.toMaterialColorScheme(dark = dark)

    CompositionLocalProvider(
        LocalSemantic provides semantic,
        LocalPaletteProvider provides provider,
    ) {
        MaterialTheme(
            colorScheme = materialScheme,
            content = content,
        )
    }
}

private fun SemanticPalette.toMaterialColorScheme(dark: Boolean): ColorScheme {
    val base = if (dark) darkColorScheme() else lightColorScheme()
    return base.copy(
        surface          = this[SemanticToken.SurfaceChrome],
        onSurface        = this[SemanticToken.TextPrimary],
        surfaceVariant   = this[SemanticToken.SurfaceSunken],
        onSurfaceVariant = this[SemanticToken.TextSecondary],
        primary          = this[SemanticToken.AccentFill],
        onPrimary        = this[SemanticToken.TextOnBrand],
        primaryContainer = this[SemanticToken.AccentFillSubtle],
        background       = this[SemanticToken.SurfaceCanvas],
        onBackground     = this[SemanticToken.TextPrimary],
        outline          = this[SemanticToken.BorderDefault],
        outlineVariant   = this[SemanticToken.BorderSubtle],
        error            = this[SemanticToken.TextDanger],
    )
}
