# Webkitium — Windows shell

First reference implementation of a webkitium chrome. WinUI 3 + Windows App SDK + C++/WinRT. Targets **Windows 11 build 22621** and above (Mica requires 22000+, MicaAlt requires 22621+).

## Scope of the current sketch

This is a *seed*, not a complete browser. It demonstrates the pieces that matter for validating the architecture:

- [x] Window with **Mica** backdrop (the system material)
- [x] Custom title bar integration (omnibar sits in the title bar band)
- [x] **Omnibar** component following `design/components/omnibar/SPEC.md` — pill shape, `shape.omnibar` radius, leading lockmark, trailing actions
- [x] Token consumption from a single **ResourceDictionary** (`Tokens.xaml`) that mirrors the output of `browser/color/ColorRamp.cpp` for webkitium's default seed
- [x] Light / Dark `ThemeDictionaries` that automatically follow the system appearance
- [x] **Runtime palette updates** — `PaletteProvider` mutates the `SolidColorBrush` DPs in place; every bound control repaints without tearing down the visual tree. Bound to a dev-only **Ctrl+Shift+T** shortcut that cycles four test seeds (blue → magenta → green → near-mono) so the end-to-end OKLCH pipeline is visually verifiable.
- [ ] WebView2 content area — stubbed, to be wired when we integrate the WebKit Windows port
- [ ] Tab strip — not started
- [ ] Context menu component
- [ ] Settings window (stubbed sections planned: Paired devices, Theme, Passwords)
- [ ] Authenticator window
- [ ] `browser.theme` extension API wiring — `PaletteProvider::ApplySeed` is the implementation target, exposed through the extension API host once that's ported

## File layout

```
chrome/windows/
├── README.md                    this file
├── Package.appxmanifest         MSIX package manifest
├── src/
│   ├── App.xaml                 Application-level ResourceDictionary merge
│   ├── App.xaml.h / .cpp        Application bootstrap + activation
│   ├── MainWindow.xaml          Top-level window (Mica, title bar, layout)
│   ├── MainWindow.xaml.h / .cpp Mica backdrop setup, title bar customization
│   ├── Omnibar.xaml             Omnibar UserControl (pill, lockmark, input)
│   ├── Omnibar.xaml.h / .cpp    Omnibar behavior (focus, keyboard, submit)
│   ├── Tokens.xaml              ResourceDictionary with every semantic color/size
│   │                            — values are the algorithm's output for the default seed
│   └── Tokens.h                 Same values as C++ constants for code that needs them
```

## How to build

You need a Windows 11 dev machine with:

1. **Visual Studio 2022** (17.9 or later) with the "Desktop development with C++" and "Universal Windows Platform development" workloads.
2. **Windows App SDK 1.5+** ([download](https://learn.microsoft.com/windows/apps/windows-app-sdk/)).
3. **Windows 11 SDK 10.0.22621** or later.

From a fresh clone:

```cmd
cd chrome\windows
:: one-time: scaffold a .vcxproj matching this source layout
dotnet new winui3 --language cpp --output . --name webkitium --force

:: Visual Studio or MSBuild
msbuild webkitium.sln /p:Platform=x64 /p:Configuration=Debug
```

> **Why no committed `.vcxproj`**: Visual Studio's C++/WinRT + Windows App SDK project files are generator-managed and verbose (>1500 lines). They pin specific NuGet package versions that rot quickly. The template command above is officially supported by Microsoft and produces a current project for the SDK you have installed. Commit the resulting `.sln` / `.vcxproj` locally if you prefer reproducible builds; out of tree until the SDK situation stabilizes.

Place the generated project files at the repo's root for `chrome/windows/`. The existing `src/*.xaml*`, `src/Tokens.*`, and `Package.appxmanifest` files are drop-in; the only wiring you do in Visual Studio is:

1. Add `src/*.xaml` as `Page` items.
2. Add `src/*.cpp` as `ClCompile` items (code-behind is `<DependentUpon>` the `.xaml`).
3. Add `Package.appxmanifest` as `AppxManifest`.
4. Merge `src/App.xaml`'s merged dictionaries into the default `App.xaml`.
5. Reference the portable C++ `ng_browser_core` static library (from `browser/`) when you wire the `browser.theme` API — not required for the current visual-only sketch.

## Design decisions worth reading the code for

- **Mica in XAML, not code.** `<Window.SystemBackdrop><MicaBackdrop Kind="Base"/></Window.SystemBackdrop>` — one line. No `MicaController`, no `SystemBackdropController` boilerplate. Works from Windows App SDK 1.3+.
- **ExtendsContentIntoTitleBar**. The omnibar lives *in* the title bar region. We call `SetTitleBar(OmnibarHost)` so the OS knows which part is draggable. This mirrors Edge's title bar treatment.
- **ThemeDictionaries, not code-switching.** Light and dark palettes both ship in `Tokens.xaml`; XAML resolves them automatically as the system appearance changes. No theme-change event handler needed.
- **Tokens.xaml values are algorithmic output, committed.** The hex values match `GeneratePalette(kDefaultBrandSeed)` in `browser/color/ColorRamp.cpp`. When a user themes their browser, the runtime regenerates this dictionary from their seed (not implemented yet in this sketch — tracked under `browser.theme` wiring).
- **No Fluent accent tinting on Mica.** Default `MicaBackdrop Kind="Base"` has `TintColor=null`, i.e., no brand tint through the material. Brand appears in discrete accent surfaces (buttons, selection, focus ring) rather than being smeared across the whole window. This reads cleaner against Windows 11's aesthetic.
- **No RevealBrush on buttons.** The Fluent "light-follows-cursor" hover effect is dated in 2026. Disabled by default; re-enable via the `ClassicWindowsTheme` preset (future).
- **No `SystemAccentColor` following.** Once a user has a webkitium theme, we stop following the Windows accent color. Pre-theme first-run uses the algorithmic default (webkitium blue), not the system accent.

## What comes next

1. **Wire the browser.theme runtime updates** — `Tokens.xaml` values become merged dictionaries refreshed from `GeneratePalette()` on token change.
2. **Context menu component** following `design/components/context-menu/SPEC.md`.
3. **Settings window** with `NavigationView` sidebar and MicaAlt backdrop.
4. **WebView2 content area** stub → real WebKit Windows port integration.
5. **Authenticator window** — a separate `Window` with a locked `Tokens` dictionary (the secure-ui tokens from `design/tokens/secure-ui/`), drawn by the browser process rather than any renderer.
