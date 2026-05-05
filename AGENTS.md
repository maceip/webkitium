## Cursor Cloud specific instructions

### Product overview

Webkitium is a multi-platform browser built on downstream WebKit/WPE. The repo has four pillars: orchestrator, WebKit patches, per-platform chrome shells, and a shared portable C++ core. See `docs/ARCHITECTURE.md` for details.

On Linux (the Cloud Agent environment), two components are buildable and testable:

1. **`browser/` — Shared C++ core** (CMake + Ninja + Protobuf)
2. **`chrome/linux/` — GTK4/libadwaita shell** (Meson, but see caveat below)

### Building the C++ core

```bash
cd browser
cmake -B build -G Ninja
cmake --build build
ctest --test-dir build --output-on-failure
```

All 6 tests (smoke, sync, wire adapter, color, bridge, manifest loader) should pass.

### Building the Linux GTK shell

The `chrome/linux/meson.build` references `browser/` sources via an absolute path (`meson.project_source_root() / '..' / '..'`), which Meson rejects regardless of version. A manual compilation works:

```bash
CFLAGS="$(pkg-config --cflags gtk4 libadwaita-1) -I browser -I /tmp/webkitium-build"
# (create a config.h with APP_ID, APP_VERSION, HAVE_WEBKIT defines)
# Compile browser/ bridge .cc/.cpp files, then chrome/linux/src/*.c files
# Link with: $(pkg-config --libs gtk4 libadwaita-1) -lstdc++
```

The resulting `webkitium` binary is a GTK4 browser shell. It runs under `Xvfb` (headless X11):

```bash
Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99
./webkitium
```

### Linting

No dedicated linter configuration (`.clang-format`, `.clang-tidy`, ESLint, etc.) exists. Code quality is enforced via compiler warnings (`-Wall -Wextra -Wpedantic`) in the CMake build.

### Python CI scripts

- `python3 config/ci_matrix_env.py` — emits env vars from `config/webkit-build-matrix.json`
- `python3 config/verify_webkit_pin_commit.py --check-vcpkg` — validates vcpkg baseline alignment

Both run with Python 3.12 (system default), no extra pip dependencies needed.

### Required system packages (Linux)

- `cmake`, `ninja-build`, `protobuf-compiler`, `libprotobuf-dev` — for `browser/` build
- `libgtk-4-dev`, `libadwaita-1-dev` — for `chrome/linux/` shell
- `meson` (via pip: `pip3 install meson`) — Meson build system
- `xvfb`, `xdotool` — for headless GUI testing

### Notes

- WebKitGTK (`webkitgtk-6.0`) is optional; the shell compiles and runs without it (web view shows a placeholder).
- No databases, Docker, or external services are required for local development.
- The `orchestrator/` directory is referenced in docs but absent from this checkout.
