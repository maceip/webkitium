# Linux GTK chrome

Requires **`WEBKIT_GTK_BUILD`** pointing at the pinned GTK port output (`…/WebKitBuild/GTK/Debug`). Will not build against distro `libwebkitgtk`.

```bash
export WEBKIT_GTK_BUILD="$HOME/webkit-src/WebKitBuild/GTK/Debug"
cd chrome/linux && cargo build --release
```

Optional: `WEBKITIUM_LAUNCH_URL`, `WEBKITIUM_PROFILE_DIR`.
