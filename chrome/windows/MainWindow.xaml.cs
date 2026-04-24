// MainWindow.  Extends WinUIEx.WindowEx so we get PersistenceId,
// proper Mica backdrop plumbing, and message-hook plumbing for free.
//
// Deliberate non-goals here (handled elsewhere):
//   - Title bar drag regions: WindowEx + TabView handle this.
//   - HotKey registration: we use ordinary KeyboardAccelerators bound
//     in XAML where scoped, and WinUIEx.WindowMessageMonitor when we
//     eventually need WM_HOTKEY for global shortcuts.

using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.System;
using WinUIEx;

namespace Webkitium;

public sealed partial class MainWindow : WindowEx
{
    public MainWindow()
    {
        InitializeComponent();

        // Custom title bar with the TabView sitting in it.  WindowEx's
        // default title-bar handling works with TabView out of the box
        // -- the interactive regions inside TabView are passthrough
        // automatically.
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(TitleBarStrip);

        // Dev-only palette cycle.  Ctrl+Shift+T walks the four test
        // seeds; lives here until the Settings -> Theme page has been
        // reached for real.
        var cycle = new Microsoft.UI.Xaml.Input.KeyboardAccelerator
        {
            Modifiers = VirtualKeyModifiers.Control | VirtualKeyModifiers.Shift,
            Key = VirtualKey.T,
        };
        cycle.Invoked += (_, e) => { App.Current.Palette.CycleDevSeed(); e.Handled = true; };

        var openSettings = new Microsoft.UI.Xaml.Input.KeyboardAccelerator
        {
            Modifiers = VirtualKeyModifiers.Control,
            Key = (VirtualKey)0xBC,  // VK_OEM_COMMA
        };
        openSettings.Invoked += (_, e) => { App.Current.OpenSettings(); e.Handled = true; };

        if (Content is FrameworkElement root)
        {
            root.KeyboardAccelerators.Add(cycle);
            root.KeyboardAccelerators.Add(openSettings);
        }
    }

    private void OnAddTab(TabView sender, object args)
    {
        sender.TabItems.Add(new TabViewItem { Header = "New Tab", IsClosable = true });
    }

    private void OnTabClose(TabView sender, TabViewTabCloseRequestedEventArgs args)
    {
        sender.TabItems.Remove(args.Tab);
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is NavigationViewItem item && item.Tag is string tag)
        {
            if (tag == "settings")
            {
                App.Current.OpenSettings();
                // Clear the selection so the Settings icon doesn't
                // remain highlighted when the settings window closes.
                Nav.SelectedItem = null;
            }
        }
    }
}
