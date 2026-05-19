# Webkitium — Linux shell

Rust + gtk4-rs chrome wired to `browser/` via bindgen (URL + suggestions FFI).

**Content engine:** does **not** link apt `libwebkitgtk-6.0`. Each tab shows a GTK placeholder until WebKitGTK/WPE from the pinned tree is embedded.

## Build

```bash
sudo apt-get install libgtk-4-dev libclang-dev libsqlite3-dev cmake pkg-config
cd chrome/linux
cargo build --release
```

## Run

```bash
./target/release/webkitium
```

Optional: `WEBKITIUM_LAUNCH_URL`, `WEBKITIUM_PROFILE_DIR` for harness/CI.
