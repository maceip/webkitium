using Microsoft.UI.Xaml.Controls;
using WinUIEx;

namespace Webkitium.Settings;

public sealed partial class SettingsWindow : WindowEx
{
    public SettingsWindow()
    {
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(TitleBarStrip);
        ContentFrame.Navigate(typeof(PairedDevicesPage));
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is NavigationViewItem item && item.Tag is string tag)
        {
            switch (tag)
            {
                case "paired-devices":
                    ContentFrame.Navigate(typeof(PairedDevicesPage));
                    break;
                case "theme":
                    ContentFrame.Navigate(typeof(ThemePage));
                    break;
                case "passwords":
                    ContentFrame.Navigate(typeof(PasswordsPage));
                    break;
            }
        }
    }
}
