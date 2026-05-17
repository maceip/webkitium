# Webkitium — Windows shell

Starter kit. C# / WinUI 3 / Windows App SDK 1.6 + WebView2, with the C++ browser core (`browser/url/`, `browser/suggestions/`) compiled into `webkitium_core.dll` and consumed via cdecl P/Invoke (`LibraryImport` source generator).

## What this gives you

- A single MainWindow (1200×800) hosting a `TabView` (multi-tab) with one `WebView2` per tab, a `CommandBar` with `AutoSuggestBox` URL bar + bookmark star + secondary back/forward/reload/find commands, a horizontal bookmarks bar (`ItemsRepeater`), and a find-on-page overlay.
- Five `features.yaml` rows wired end-to-end:
  - `back_forward_navigation` — `AppBarButton` Back/Forward, sensitivity bound to `CoreWebView2.CanGoBack/Forward` via `NavigationCompleted` (those properties don't raise `PropertyChanged`, so we refresh manually).
  - `multiple_tabs` — `TabView` with `IsAddTabButtonVisible="True"`, `TabCloseRequested`, Ctrl+T / Ctrl+W accelerators.
  - `url_autocomplete` — `AutoSuggestBox` driven by `wk_suggestions_query`; suggestion popup is WinUI-native.
  - `bookmarks_persist` — star toggle via `wk_suggestions_set_bookmarked`, bookmarks bar reads `wk_suggestions_bookmarks_flat`.
  - `find_on_page` — overlay over an injected JS find-controller (WebView2 has no native Find API, so we use the canonical Chromium-on-Windows `ExecuteScriptAsync` pattern: walk text nodes, wrap matches in `<mark>`, return counts via `JSON.stringify`).
- Profile directory comes from a `--profile-dir=<path>` CLI flag (harness-friendly) or defaults to `%LocalAppData%\Webkitium`.

## Prerequisites

- Windows 11 22H2 or newer
- Visual Studio 2022 17.10+ with the **.NET Desktop**, **Universal Windows Platform**, and **Desktop C++** workloads
- Windows App SDK 1.6 (VS installer or NuGet)
- .NET 8 SDK
- WebView2 Runtime (pre-installed on Windows 11)
- MSVC v143 toolchain (ships with VS 2022)
- vcpkg integrated with Visual Studio (`vcpkg integrate install`) — the BrowserCore vcxproj uses **manifest-mode vcpkg** (see `vcpkg.json` at this directory) to pull in `sqlite3` at build time. No protobuf dependency: the four C ABI sources compiled here use only `<sqlite3.h>`.

## Build

```
dotnet restore Webkitium.sln
dotnet build Webkitium.sln -c Debug -p:Platform=x64
```

Or open `Webkitium.sln` in Visual Studio and press F5.

## Run

```
.\Webkitium\bin\x64\Debug\net8.0-windows10.0.19041.0\Webkitium.exe
```

## What you do next

Your roadmap is [`features.yaml`](../../features.yaml) at the repo root. Pick a row, implement the feature with native WinUI 3 widgets, then add a smoke test in [`harness_windows/`](../../harness_windows/) using UIAutomation. CI goes red when a `required: true` feature lacks a passing test once the harness is wired up.

## Honest caveats

This was authored on macOS. Predictable failure surfaces, ranked by likelihood:

1. **CI-verified on `windows-latest` (Windows Server 2022 + VS 2022 build tools)** — see [`.github/workflows/windows-ci.yml`](../../.github/workflows/windows-ci.yml). First local-Windows build may still hit App SDK version skew if your installed VS lags the runner; mitigation: `dotnet workload update`, then re-run `dotnet restore`.
2. **vcpkg manifest resolution for sqlite3.** `BrowserCore.vcxproj` sets `VcpkgEnableManifest=true` and `vcpkg.json` lists `sqlite3`. If link fails with `unresolved external symbol sqlite3_*`, your vcpkg either isn't integrated (`vcpkg integrate install` from an Admin shell) or the manifest didn't restore — check the build log for the `vcpkg install` step. Worst case: vendor the sqlite3 amalgamation (`sqlite3.c` + `sqlite3.h`) directly into `BrowserCore/` and drop the vcpkg dep.
3. **WebView2 runtime.** Auto-installed on Windows 11. On Server / LTSC SKUs you may need the Evergreen bootstrapper.
4. **P/Invoke calling convention.** The C ABI is cdecl; `LibraryImport` defaults to `Winapi` (which is `Stdcall` on x86). All five FFI methods carry an explicit `[UnmanagedCallConv(CallConvs = [CallConvCdecl])]` — if you see `BadImageFormatException` on first FFI call, an attribute is missing on a method you added.
5. **DLL search path.** `webkitium_core.dll` must sit alongside `Webkitium.exe` at runtime. The `<ProjectReference>` and the explicit `CopyBrowserCoreDll` MSBuild target in `Webkitium.csproj` both copy it; if it isn't there after build, check `$(BrowserCoreOutputDir)` resolution and that the vcxproj actually produced output for that Platform/Configuration combination.
6. **CRT runtime library mismatch.** The vcxproj uses `MultiThreadedDLL` (`/MD`) in Release and `MultiThreadedDebugDLL` (`/MDd`) in Debug — both match .NET's dynamic CRT expectation. If link errors mention `_CrtIsValidHeapPointer` or you see "different runtime libraries" warnings, something forced static CRT.
7. **`WebView2.ExecuteScriptAsync` return-value double-quoting.** WebView2's `ExecuteScriptAsync` always returns a *JSON-encoded* string of whatever the script's final expression evaluates to. The find controller therefore stringifies its own result (`JSON.stringify(window.__wkFind.search(q))`) and the C# side does two parses (outer string → inner object). If find shows `?/?` for the match count, the inner parse failed — most likely the page's CSP blocked our `<mark>` insertion, or a previous `<mark>` from a prior search leaked into the DOM.
8. **AutoSuggestBox + URL bar feedback loop.** Setting `AutoSuggestBox.Text` from code fires `TextChanged` with `Reason == ProgrammaticChange`; we filter on `UserInput` to avoid querying SQLite on every page navigation that mirrors the new URL into the bar. If you see a barrage of `wk_suggestions_query` calls on navigation, that filter is missing on a new code path.

## Harness coverage

The five features above each have a smoke test under [`harness_windows/tests/`](../../harness_windows/tests/) driving the app via UIAutomation (FlaUI.UIA3). CI invokes them with `dotnet test --filter "Trait=Smoke"`.
