// Project-level plugins. Versions tracked via libs.versions.toml would be
// nicer but overkill for a single-module app.

plugins {
    id("com.android.application") version "8.5.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.0" apply false
}
