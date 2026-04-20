# Windows Chrome

Target stack: Windows App SDK, WinUI 3, `TabView`, native titlebar integration, and WebView2 samples as reference material.

Compile baseline:

```powershell
cd chrome\windows\WebkitiumChrome
dotnet build
```

The best Microsoft browser sample is WebView2Browser. It is not the desired final shell because it is Win32/C++ and uses web-rendered controls, but it is valuable for tab behavior, history, address handling, security state, and multi-WebView patterns. The product shell should be WinUI 3.

Reference:

- https://learn.microsoft.com/en-us/microsoft-edge/webview2/samples/webview2-winui3-sample
- https://github.com/MicrosoftEdge/WebView2Browser
- https://github.com/MicrosoftEdge/WebView2Samples
