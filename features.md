# Features

`features.yaml` is the source of truth for cross-platform conformance. CI fails if any feature with `required: true` lacks a passing smoke test on a platform.

## Platform matrices

The platform row `platform:linux-gtk-wayland` (`kind: platform`) at the bottom of `features.yaml` records Linux GTK + Wayland UI coverage. It uses the `desktop_full` profile: every globally `required: true` feature must appear under `implemented` or `planned`. Platform-only requirements (for example `url_secure_indicator`) are listed under `required_additive`.

## How to add a feature

1. Add a row to `features.yaml` (id, name, description, required, category).
2. Update the relevant platform row (`kind: platform`) `{implemented,planned,not_applicable}` lists.
3. Write a smoke test in your platform's `harness_<platform>/` directory keyed by the same `id`.
4. CI runs every platform's harness against `features.yaml`. A `required: true` feature with no passing test on a platform fails that platform red.

Platform-specific extras live only in that platform's harness. They do not belong in the feature rows unless they are shared catalog entries.
