package org.webkitium.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import org.webkitium.android.ui.BrowserScreen
import org.webkitium.android.ui.theme.WebkitiumTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            WebkitiumTheme {
                BrowserScreen()
            }
        }
    }
}
