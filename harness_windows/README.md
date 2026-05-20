# Webkitium — Windows test harness

C# / .NET 8 / xUnit smoke tests driving `chrome/windows/Webkitium.exe` via UIAutomation through [FlaUI.UIA3](https://github.com/FlaUI/FlaUI).

**Prerequisite:** WinUI shell built with `WebKitHost` / pinned `WebKit.dll` (not WebView2). See [`docs/ENGINE_EMBED.md`](../docs/ENGINE_EMBED.md).

## Layout

- `Webkitium.Harness.sln` / `Webkitium.Harness.csproj` — solution + project, separate from `chrome/windows/Webkitium.sln` (keeps dev/test boundaries clean).
- `tests/HarnessFixture.cs` — per-test fixture: spawns Webkitium with a temp `--profile-dir`, finds the main window, exposes element lookup helpers, tears down on dispose.
- `tests/{BackForward,MultipleTabs,UrlAutocomplete,BookmarkToggle,FindOnPage}Tests.cs` — one smoke per `features.yaml` ID. All carry `[Trait("Smoke", "true")]`.

## Run

```
dotnet test Webkitium.Harness.sln -c Debug
```

Or filter to smoke only:

```
dotnet test --filter "Trait=Smoke"
```

The harness locates `Webkitium.exe` by walking up from `AppContext.BaseDirectory` looking for `chrome\windows\Webkitium\bin\x64\{Debug,Release}\net8.0-windows10.0.19041.0\Webkitium.exe`. Override with the `WEBKITIUM_EXE` environment variable for CI.

## Conventions for adding a feature

1. Add the row to `features.yaml` at the repo root.
2. Implement on `chrome/windows/Webkitium/`. Name every load-bearing control with `AutomationProperties.Name="<stable string>"` — that's how the harness finds it.
3. Add a `*Tests.cs` in `tests/` carrying `[Trait("Feature", "<features.yaml id>")]`.
4. CI runs `dotnet test --filter "Trait=Smoke"` and fails on any unimplemented `required: true` row.

## Driver choice — FlaUI vs raw UIAutomation

FlaUI wraps `UIAutomationClient` in a saner managed surface (`FindFirstByName`, `AsButton`, `Invoke`) and is the de-facto Windows UI-test library on GitHub. Raw UIAutomation requires COM marshalling and a lot of `Cast<IInvokeProvider>()` boilerplate. Chromium's Windows UI tests do similar — abstract over the low-level COM API.
