# Webkitium — GTK Linux shell

Minimal starter kit. Rust + [gtk4-rs](https://gtk-rs.org/gtk4-rs/) + [webkit6](https://crates.io/crates/webkit6) (WebKitGTK 6.0, GNOME 46+). Links the C++ browser core at `../../browser/` statically via `bindgen` over the two C ABI headers (`url/UrlBridgeC.h`, `suggestions/SuggestionsBridgeC.h`).

## System prerequisites

Ubuntu 24.04 / Debian trixie:

```
sudo apt install libgtk-4-dev libwebkitgtk-6.0-dev libclang-dev \
                 libprotobuf-dev protobuf-compiler cmake gcc pkg-config
```

Fedora 40+: `sudo dnf install gtk4-devel webkitgtk6.0-devel clang-devel protobuf-devel protobuf-compiler cmake gcc pkgconf`

Arch: `sudo pacman -S gtk4 webkitgtk-6.0 clang protobuf cmake gcc pkgconf`

## Build & run

```
cd chrome/linux
cargo build --release
cargo run
```

The first build invokes cmake on `../../browser/` to produce `libng_browser_core.a`; subsequent builds are incremental.

## What this gives you

- One window: HeaderBar with back / forward / reload + URL `Entry`, WebKitGTK `WebView` filling the body.
- URL submission round-trips through the C++ core (`wk_url_normalize`) — the proof-of-life FFI call.

## Wayland

The chosen stack (GTK4 + WebKitGTK 6.0) is Wayland-native by design — that's the default session on every supported distro above. Things to verify on a Wayland session:

- Confirm session type: `echo $XDG_SESSION_TYPE` should print `wayland`. Force if needed: `GDK_BACKEND=wayland cargo run`.
- WebKitGTK uses DMA-BUF for video / canvas / WebGL on Wayland; Mesa is the required driver and is standard on modern distros. If hardware rendering falls back to software, set `WEBKIT_DISABLE_DMABUF_RENDERER=1` to confirm it's the DMA-BUF path that's failing.
- Smoke-test these surfaces explicitly — they all go through XDG Desktop Portals on Wayland and are the common breakage points: clipboard copy/paste in the WebView, drag-and-drop into the window, taking a screenshot, opening file picker for download / upload.
- X11 sessions still work: same binary with `GDK_BACKEND=x11`. Useful as a fallback when debugging Wayland-specific issues.

## What you do next

Your roadmap is [`features.yaml`](../../features.yaml) at the repo root. Pick a row, implement the feature with native GTK widgets, then add a smoke test in [`harness_linux/`](../../harness_linux/). CI will go red if a `required: true` feature lacks a passing test once the harness is wired up.

## Honest caveats

**`cargo check --release` verified inside a `rust:latest` (1.95) Debian Bookworm container** with `libgtk-4-dev libwebkitgtk-6.0-dev libclang-dev libprotobuf-dev libsqlite3-dev protobuf-compiler cmake pkg-config` installed. bindgen + gtk4-rs + webkit6 all resolve; the FFI wrappers type-check. 5 `dead_code` warnings on unhooked scaffolding (`Index`, `scrub_tracking`, `search_url`, `suggest_url`) — intentional, those land when their `features.yaml` rows are implemented.

**Not yet verified:** end-to-end `cargo build` (which actually invokes cmake on `../../browser/` and links). The static-link directives in `build.rs` may surface ordering or missing-symbol issues there. Runtime on a real Wayland desktop is likewise untested — first Linux engineer should `cargo run` and report:

- Whether `cmake` configures the browser core cleanly (most likely friction: `protobuf` version skew with system pkg).
- Whether the link succeeds (predicted gap: distro-specific runtime libs we missed beyond `stdc++ sqlite3 pthread protobuf`).
- Whether `webkit6::WebView` renders content under Wayland with default DMA-BUF rendering.
