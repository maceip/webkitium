package dev.webkitium.theme

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Runtime palette applier for the Android shell.
 *
 * Analog of:
 *   chrome/windows/src/PaletteProvider.{h,cpp}   (SolidColorBrush mutation)
 *   chrome/macos/.../PaletteProvider.swift       (ObservableObject + @Published)
 *
 * Design parity goals:
 *  - Same algorithm (browser/color/ via JNI).
 *  - Same semantic token set + ordering.
 *  - Same dev seed rotation so a reviewer can eyeball all three shells
 *    flipping through the same palettes.
 */
class PaletteProvider : ViewModel() {

    data class Snapshot(
        val seedArgb: Int,
        val light: SemanticPalette,
        val dark: SemanticPalette,
    )

    private val _state = MutableStateFlow(
        buildSnapshot(ColorBridge.DEFAULT_BRAND_SEED_ARGB)
    )
    val state: StateFlow<Snapshot> = _state.asStateFlow()

    /**
     * Apply a new brand seed.  Resolves both appearances; Compose re-
     * renders bound composables via StateFlow collection in
     * [WebkitiumTheme].
     */
    fun applySeed(argb: Int) {
        _state.value = buildSnapshot(argb)
    }

    /**
     * Dev-only cycle.  Same four seeds as the Windows and macOS shells
     * so side-by-side comparisons work.  Removed once Settings ->
     * Appearance -> Theme ships.
     */
    fun cycleDevSeed() {
        devSeedIndex = (devSeedIndex + 1) % DEV_SEEDS.size
        applySeed(DEV_SEEDS[devSeedIndex])
    }

    private var devSeedIndex = 0

    private fun buildSnapshot(seedArgb: Int) = Snapshot(
        seedArgb = seedArgb,
        light = SemanticPalette.resolve(seedArgb, dark = false),
        dark = SemanticPalette.resolve(seedArgb, dark = true),
    )

    companion object {
        private val DEV_SEEDS = intArrayOf(
            ColorBridge.DEFAULT_BRAND_SEED_ARGB, // webkitium blue
            0xFFD21F6B.toInt(),                  // magenta
            0xFF2D7A3E.toInt(),                  // forest green
            0xFF454B55.toInt(),                  // near-monochrome
        )
    }
}
