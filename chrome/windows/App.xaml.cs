// Application entry point. Bootstraps the shared PaletteProvider, the
// wired-but-inactive BrowserServices (extensions / sync / webauthn),
// and opens MainWindow on activation.

using Microsoft.UI.Xaml;
using Webkitium.Platform;
using Webkitium.Theme;

namespace Webkitium;

public partial class App : Application
{
    public App()
    {
        InitializeComponent();
    }

    internal static App Current => (App)Application.Current;

    internal PaletteProvider Palette { get; } = new();

    // Process-wide controllers from browser/.  Constructed lazily so a
    // P/Invoke failure during App() does not block the shell from
    // launching with palette-only fallbacks.  Settings pages read from
    // these; no UI invokes them yet.
    internal BrowserServices? Services { get; private set; }

    internal MainWindow? MainWindow { get; private set; }

    internal Settings.SettingsWindow? SettingsWindow { get; private set; }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        // Populate the palette caches and push the default seed once the
        // XAML resource tree is live.
        Palette.Initialize(Resources);
        Palette.ApplySeed(Platform.WebkitiumColorNative.DefaultBrandSeedArgb);

        try
        {
            Services = new BrowserServices();
        }
        catch (System.Exception ex)
        {
            // Native sidecar missing or stale -- log and continue with
            // palette-only chrome.  Settings surfaces handle null Services.
            System.Diagnostics.Debug.WriteLine(
                $"BrowserServices failed to initialize: {ex.Message}");
        }

        MainWindow = new MainWindow();
        MainWindow.Activate();
    }

    internal void OpenSettings()
    {
        SettingsWindow ??= new Settings.SettingsWindow();
        SettingsWindow.Activate();
    }
}
