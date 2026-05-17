# Android platform harness

Smoke-test runner for the Android shell at `chrome/android/`. Drives the app via Espresso + UIAutomator, asserts against rows from `features.yaml`.

## Status

Empty stub. First test to land: `url_autocomplete` — type into the URL bar and assert the suggestions popover appears.

## Approach

- Instrumented tests live in `chrome/android/app/src/androidTest/`
- Compose semantics + UIAutomator for outside-app surfaces (system permission dialogs, file pickers via SAF)
- Each row in `features.yaml` with `required: true` needs one passing test or CI goes red

## How to add a test

1. Pick a row from `../features.yaml`
2. Add a `@Test` method to a class under `chrome/android/app/src/androidTest/kotlin/org/webkitium/android/harness/`
3. Run: `./gradlew connectedDebugAndroidTest`
