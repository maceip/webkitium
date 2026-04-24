// Application entry point. Bootstraps the shared PaletteProvider and
// opens MainWindow on activation.

using Microsoft.UI.Xaml;
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

    internal MainWindow? MainWindow { get; private set; }

    internal Settings.SettingsWindow? SettingsWindow { get; private set; }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        // Populate the palette caches and push the default seed once the
        // XAML resource tree is live.
        Palette.Initialize(Resources);
        Palette.ApplySeed(Platform.WebkitiumColorNative.DefaultBrandSeedArgb);

        MainWindow = new MainWindow();
        MainWindow.Activate();
    }

    internal void OpenSettings()
    {
        SettingsWindow ??= new Settings.SettingsWindow();
        SettingsWindow.Activate();
    }
}
