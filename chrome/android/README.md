# Android Chrome

Target stack: Kotlin, Jetpack Compose, Material 3, edge-to-edge UI, adaptive layouts, and predictive back.

Android does not currently provide a first-party WebView Composable. The initial shell should use Compose for browser chrome and host the engine surface through `AndroidView`, then route back gestures through tab history, tab close, and app exit in that order.

Reference:

- https://developer.android.com/develop/ui/views/layout/webapps/in-app-browsing-embedded-web
- https://developer.android.com/jetpack/androidx/releases/compose-material3-adaptive
- https://github.com/KevinnZou/compose-webview-multiplatform
