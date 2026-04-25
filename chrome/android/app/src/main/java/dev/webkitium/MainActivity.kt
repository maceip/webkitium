package dev.webkitium

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.weight
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import dev.webkitium.services.BrowserServices
import dev.webkitium.theme.LocalPaletteProvider
import dev.webkitium.theme.LocalSemantic
import dev.webkitium.theme.SemanticToken
import dev.webkitium.theme.WebkitiumTheme
import dev.webkitium.ui.Omnibar

class MainActivity : ComponentActivity() {
    // Wired-but-inactive: ExtensionRegistry, Sync stub, and
    // WebAuthnController are constructed once at activity launch.  No
    // surface invokes them yet; the holder exists so future Settings
    // pages can read state without bootstrapping a service-per-call.
    private var services: BrowserServices? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        services = BrowserServices.create()

        // Edge-to-edge + predictive back.  Android 14+ enables the back
        // gesture automatically when android:enableOnBackInvokedCallback
        // is true in the manifest, which it is.
        enableEdgeToEdge()
        setContent {
            WebkitiumTheme {
                RootScreen()
            }
        }
    }

    override fun onDestroy() {
        services?.dispose()
        services = null
        super.onDestroy()
    }
}

@Composable
private fun RootScreen() {
    val semantic = LocalSemantic.current
    val provider = LocalPaletteProvider.current

    // Dev-only: three-finger tap anywhere cycles seeds.  Uses
    // pointerInput with awaitPointerEvent rather than
    // detectTapGestures so we can count fingers precisely.
    val devCycleModifier = Modifier.pointerInput(provider) {
        detectTapGestures(
            onLongPress = {
                // Three-finger-or-more long press -> cycle.  In Compose
                // we can't easily count fingers in detectTapGestures,
                // so fall back to long-press here.  TODO: replace with
                // proper three-finger detection when Settings ships.
                provider?.cycleDevSeed()
            }
        )
    }

    Surface(
        modifier = Modifier
            .fillMaxSize()
            .background(semantic[SemanticToken.SurfaceCanvas])
            .then(devCycleModifier),
        color = semantic[SemanticToken.SurfaceCanvas],
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .padding(horizontal = 12.dp)
        ) {
            // Content placeholder (web content area).
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .weight(1f)
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Web content goes here",
                    color = semantic[SemanticToken.TextTertiary],
                )
            }

            // Floating omnibar pill at the bottom per Android idiom.
            Omnibar(modifier = Modifier.padding(bottom = 12.dp))
        }
    }
}
