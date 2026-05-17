# Features

`features.yaml` is the source of truth for cross-platform conformance. CI fails if any feature with `required: true` lacks a passing smoke test on a platform.

## How to add a feature

1. Add a row to `features.yaml` (id, name, description, required, category).
2. Write a smoke test in your platform's `harness_<platform>/` directory keyed by the same `id`.
3. CI runs every platform's harness against `features.yaml`. A `required: true` feature with no passing test on a platform fails that platform red.

Platform-specific extras live only in that platform's harness. They do not belong in `features.yaml`.
