# Windows Chrome

Target stack: Windows App SDK, WinUI 3, `TabView`, native titlebar integration, and WebView2 samples as reference material.

Compile baseline:

```powershell
cd chrome\windows\WebkitiumChrome
dotnet build
```

Horizon is the strongest current open-source WinUI browser reference found so far. It has a real browser-shaped WinUI shell, tab collection, close UI, WebContentHost, split tabs, and current Windows SDK/.NET expectations. It is GPL-3.0, so treat it as reference material unless the product intentionally accepts GPL-derived code.

Microsoft's WebView2Browser remains useful for browser behavior and WebView2 API coverage. It is not the desired final shell because it is Win32/C++ and uses web-rendered controls. The product shell should be WinUI 3.

Tabs are currently WinUI `TabViewItem`s with close and reorder enabled.

Reference:

- https://github.com/horizon-developers/browser
- https://learn.microsoft.com/en-us/microsoft-edge/webview2/samples/webview2-winui3-sample
- https://github.com/MicrosoftEdge/WebView2Browser
- https://github.com/MicrosoftEdge/WebView2Samples
