# Linux GTK chrome

Rust + GTK 4 shell hosting **pinned WebKitGTK** via `webkit6::WebView`. Will **not** compile against distro `libwebkitgtk` — `WEBKIT_GTK_BUILD` is mandatory (`chrome/linux/build.rs`).

## Build

```bash
export WEBKIT_GTK_BUILD="$HOME/webkit-src/WebKitBuild/GTK/Debug"
export PKG_CONFIG_PATH="$WEBKIT_GTK_BUILD/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
cd chrome/linux && cargo build --release
```

## Run

```bash
export WEBKITIUM_LAUNCH_URL='https://en.wikipedia.org'   # optional CI seed
./target/release/webkitium   # binary name from Cargo.toml
```

Use `scripts/run_chrome_with_engine.sh linux-gtk [engine-root]` for a bundled layout.

## CI

- `linux-gtk-build` — bundles `engine/` + chrome when `WEBKIT_GTK_BUILD` tree exists on runner
- `browser-shell-screenshots` — Xvfb capture + lock/content asserts
- **`linux-ci.yml` deleted** — never use apt WebKitGTK for release proof

## Features

Desktop UI lives under `chrome/linux/src/ui/` (see [`features.yaml`](../../features.yaml) `platform:linux-gtk-wayland`). Phase 0 engine events: `ui/webkit_events.rs`. Full phased plan: [`docs/LINUX_UI_WIRING_PLAN.md`](../../docs/LINUX_UI_WIRING_PLAN.md). Build requires `WEBKIT_GTK_BUILD` pointing at the pinned WebKitGTK tree.

```bash
export WEBKIT_GTK_BUILD=/path/to/WebKitBuild/GTK/Debug
cd chrome/linux && cargo build --release
```

## Harness

[`harness_linux/`](../../harness_linux/) — AT-SPI smoke tests (require running app + pinned engine on PATH).

## Docs

[`docs/ENGINE_EMBED.md`](../../docs/ENGINE_EMBED.md) · [`docs/CHROME_PLATFORM_REVIEW.md`](../../docs/CHROME_PLATFORM_REVIEW.md)
