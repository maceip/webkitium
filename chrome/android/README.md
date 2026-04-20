# Android Chrome

Target stack: Kotlin, Jetpack Compose, Material 3, edge-to-edge UI, adaptive layouts, and predictive back.

Compile baseline:

```sh
cd chrome/android
gradle :app:assembleDebug
```

Android does not currently provide a first-party WebView Composable. The initial shell uses Compose for browser chrome and hosts the engine surface through `AndroidView`.

Tabs are modeled as an adaptive supporting pane using Navigation 3 and Material 3 Adaptive. On compact screens, the tab overview is a destination. On foldables and larger screens, it can sit beside the page as a supporting pane, matching the Android nav3 supporting-pane recipe.

Reference:

- https://developer.android.com/develop/ui/views/layout/webapps/in-app-browsing-embedded-web
- https://developer.android.com/jetpack/androidx/releases/compose-material3-adaptive
- https://github.com/KevinnZou/compose-webview-multiplatform
