// Shared harness scaffolding. Each test gets a fresh profile dir + a fresh
// Webkitium.exe process, kept alive for the test body.

using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.UIA3;

namespace Webkitium.Harness;

public sealed class HarnessFixture : IDisposable
{
    public Application App { get; }
    public UIA3Automation Automation { get; }
    public Window MainWindow { get; }
    public string ProfileDir { get; }

    public HarnessFixture()
    {
        ProfileDir = Path.Combine(Path.GetTempPath(), "webkitium-harness-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(ProfileDir);

        var exe = ResolveWebkitiumExe();
        var psi = new ProcessStartInfo(exe, $"--profile-dir=\"{ProfileDir}\"")
        {
            UseShellExecute = false
        };
        App = Application.Launch(psi);
        Automation = new UIA3Automation();

        // WKView init is async — wait for the main window's "Address bar"
        // element to become available (or 15s timeout).
        Window? window = null;
        var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(15);
        while (DateTime.UtcNow < deadline)
        {
            window = App.GetMainWindow(Automation, TimeSpan.FromSeconds(2));
            if (window is not null && window.FindFirstDescendant(cf => cf.ByName("Address bar")) is not null) break;
            Thread.Sleep(250);
        }
        if (window is null) throw new InvalidOperationException("Webkitium main window never appeared.");
        MainWindow = window;
    }

    public AutomationElement FindByName(string name)
    {
        var el = MainWindow.FindFirstDescendant(cf => cf.ByName(name));
        if (el is null) throw new InvalidOperationException($"No element named '{name}'.");
        return el;
    }

    public AutomationElement? TryFindByName(string name) =>
        MainWindow.FindFirstDescendant(cf => cf.ByName(name));

    private static string ResolveWebkitiumExe()
    {
        // Try common output paths. CI overrides via WEBKITIUM_EXE env var.
        var env = Environment.GetEnvironmentVariable("WEBKITIUM_EXE");
        if (!string.IsNullOrEmpty(env) && File.Exists(env)) return env;

        var here = AppContext.BaseDirectory;
        // Walk up looking for chrome\windows\Webkitium\bin\... then \net8.0-windows10.0.19041.0\Webkitium.exe
        var dir = new DirectoryInfo(here);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "chrome", "windows", "Webkitium", "bin", "x64", "Debug", "net8.0-windows10.0.19041.0", "Webkitium.exe");
            if (File.Exists(candidate)) return candidate;
            candidate = Path.Combine(dir.FullName, "chrome", "windows", "Webkitium", "bin", "x64", "Release", "net8.0-windows10.0.19041.0", "Webkitium.exe");
            if (File.Exists(candidate)) return candidate;
            dir = dir.Parent;
        }
        throw new FileNotFoundException(
            "Could not locate Webkitium.exe. Set WEBKITIUM_EXE env var or build chrome/windows/Webkitium.sln first.");
    }

    public void Dispose()
    {
        try { App?.Close(); } catch { }
        try { App?.Dispose(); } catch { }
        try { Automation?.Dispose(); } catch { }
        try { if (Directory.Exists(ProfileDir)) Directory.Delete(ProfileDir, recursive: true); } catch { }
    }
}
