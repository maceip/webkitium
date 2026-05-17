# Windows platform harness

Smoke-test driver for the Windows shell (`chrome/windows/`). Reads `features.yaml` at the repo root and exercises each `required: true` feature against a running Webkitium build.

Driver tech: **UIAutomation** via the [`Microsoft.Windows.SDK.NET.Ref`](https://www.nuget.org/packages/Microsoft.Windows.SDK.NET.Ref) reference assemblies (UIA3 client), invoked from a small .NET 8 console runner.

First test to be added: `url_autocomplete` from `features.yaml`. Expected shape:

1. Launch `Webkitium.exe`.
2. Find the URL `TextBox` by AutomationId or name.
3. Type a partial query, wait for the suggestion popup to render.
4. Assert at least one suggestion row appears and its text contains the typed prefix.
5. Press Enter; assert the WebView2 navigates.

No test code in this directory yet — that's the platform engineer's first task after standing up the runner.
