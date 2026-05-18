# webkitium-min

Minimal Win32 + WebKit-for-Windows test program. Proves our WebKit Windows
build hosts a real `WKView` in our own HWND — no WebView2, no WinUI, no
Chromium.

`main.cpp` creates a top-level `WebkitiumMinMain` window, parents a WebKit
`WKView` child HWND to it, loads a URL, then captures the window contents
via `PrintWindow(PW_RENDERFULLCONTENT)` to PNG via WIC.

## Prereqs (already installed on the `webkitium`-labelled self-hosted runner)

- VS Build Tools at `C:\BuildTools` (`VsDevCmd.bat`)
- LLVM at `C:\Program Files\LLVM` (clang-cl, matches the WebKit build)
- CMake on PATH
- Ninja on PATH (falls back to NMake Makefiles)
- WebKit-for-Windows built at `C:\W\webkit-src\WebKitBuild\Debug` — run
  `perl Tools\Scripts\build-webkit --debug --win` from `C:\W\webkit-src`
  first, or trigger `.github/workflows/windows-build.yml`.

## Run

From a `cmd.exe` shell in this directory:

```
build.cmd
```

`build.cmd` configures, builds, copies WebKit DLLs next to the EXE, runs
the binary, and prints the screenshot path on success.

Output: `chrome\windows-min\webkitium-windows-wikipedia.png` (alongside
this README).

## Override defaults

```
set WEBKIT_SRC=D:\some\other\webkit-src
set WEBKIT_BUILD=D:\some\other\webkit-src\WebKitBuild\Release
set TARGET_URL=https://example.com
set OUT_PNG=D:\screenshots\out.png
set WAIT_SECONDS=20
build.cmd
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `WEBKIT_BUILD\bin not found` | WebKit hasn't been built yet | `cd C:\W\webkit-src && perl Tools\Scripts\build-webkit --debug --win` |
| Linker error: cannot open `WebKit.lib` | import libs land under `bin\` not `lib\` on this build | CMakeLists.txt has a fallback that checks both; if it still misses, set `-DWEBKIT_BUILD=…` to the path containing the actual `.lib` files |
| `webkitium_min.exe` launches and immediately exits | DLL not found at runtime | Ensure `build\bin\` contains `WebKit.dll`, `JavaScriptCore.dll`, `WTF.dll`, `PAL.dll`. The post-build step copies them; if it skipped, copy manually from `%WEBKIT_BUILD%\bin\` |
| Window appears but stays blank | WebKit page never finishes loading at network egress | Increase `WAIT_SECONDS`, or hit a local page first to confirm rendering |
| `PrintWindow` returns 0 | window not yet composited | The capture falls back to `BitBlt` from the screen DC; if the window is occluded or off-screen, raise the main HWND first |
| Header not found: `WebKit/WKView.h` | Forwarding headers not generated | `cd C:\W\webkit-src && perl Tools\Scripts\build-webkit --win --generate-project-only` to regenerate, then re-run `build.cmd` |

## What this is *not*

This is not the production Windows shell — that lives at
`chrome/windows/` (currently WinUI 3 with a WebView2 placeholder, the
real WebKit swap is the next change). This is a single-file proof that
our WebKit build is reachable from a non-Chromium HWND host. The same
P/Invoke pattern, once validated here, will land in the WinUI shell.
