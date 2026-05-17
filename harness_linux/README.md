# Linux platform harness

Smoke-test harness for the Webkitium GTK shell. Drives the running app via accessibility (AT-SPI), exercises the surface described by [`../features.yaml`](../features.yaml), and reports pass/fail per feature back to CI.

## Driver

Use the [`atspi`](https://crates.io/crates/atspi) Rust crate (AT-SPI 2 client) to find accessible elements on the running GTK app and dispatch actions against them. GTK4 exposes accessibility automatically — most widgets need no annotation.

## First test to add

`url_autocomplete` from `features.yaml`: type a partial query into the URL `Entry`, assert the suggestion popover appears with at least one row, assert Enter on the first row navigates the `WebView` to a non-`about:blank` URI.

## Layout (to be added)

```
harness_linux/
├── Cargo.toml          # one crate, deps: atspi, tokio, anyhow
├── src/
│   └── main.rs         # reads ../features.yaml, runs tests for each required row
└── tests/
    └── url_autocomplete.rs
```
