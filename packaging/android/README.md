# Android manifest fragments

Merge `manifest-additions.xml` into the WPE-Android app `AndroidManifest.xml` (or use `manifest merger` / Gradle `src/main/AndroidManifest.xml` overlay).

Set `usesCleartextTraffic` only if your dev server requires HTTP; **disable for production**.
