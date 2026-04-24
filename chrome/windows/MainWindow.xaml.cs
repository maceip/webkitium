// MainWindow owns tab lifecycle (create/close/switch) and routes the
// selected tab's BrowserTab UserControl into ActiveTabHost.
//
// Each TabViewItem is created without a persistent Content -- the actual
// UserControl lives in a parallel dictionary so that switching tabs only
// re-parents the selected UserControl into ActiveTabHost, and unselected
// tabs keep their WebView2 state alive without being detached.

using System;
using System.Collections.Generic;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using Webkitium.Views;
using Windows.System;
using WinUIEx;

namespace Webkitium;

public sealed partial class MainWindow : WindowEx
{
    private readonly Dictionary<TabViewItem, BrowserTab> _tabs = new();

    public MainWindow()
    {
        InitializeComponent();

        // Custom title bar with the TabView occupying the left portion
        // and a draggable filler + system-controls reserve on the right.
        // WinUIEx handles the drag region plumbing when SetTitleBar is
        // given a container that has both interactive and non-interactive
        // children.
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(TitleBarStrip);

        // Dev-only: Ctrl+Shift+T cycles test palettes.
        AddAccelerator(VirtualKey.T,
            VirtualKeyModifiers.Control | VirtualKeyModifiers.Shift,
            (_, __) => App.Current.Palette.CycleDevSeed());
        // Ctrl+, opens Settings.
        AddAccelerator((VirtualKey)0xBC,
            VirtualKeyModifiers.Control,
            (_, __) => App.Current.OpenSettings());
        // Ctrl+T creates a new tab.
        AddAccelerator(VirtualKey.T,
            VirtualKeyModifiers.Control,
            (_, __) => CreateTab(new Uri("https://example.com/")));

        // Seed with one tab.
        CreateTab(new Uri("https://example.com/"));
    }

    private void AddAccelerator(VirtualKey key, VirtualKeyModifiers mods,
                                Action<object?, object?> handler)
    {
        var accel = new Microsoft.UI.Xaml.Input.KeyboardAccelerator
        {
            Key = key,
            Modifiers = mods,
        };
        accel.Invoked += (s, e) => { handler(s, e); e.Handled = true; };
        if (Content is FrameworkElement root)
        {
            root.KeyboardAccelerators.Add(accel);
        }
    }

    private void CreateTab(Uri initialUrl)
    {
        var content = new BrowserTab { InitialSource = initialUrl };
        var item = new TabViewItem
        {
            // Favicon-only header. No text title until we wire
            // WebView2.DocumentTitleChanged / FaviconChanged.
            Header = string.Empty,
            IsClosable = true,
            Width = 46,
        };

        // Placeholder favicon: Permissions padlock in AccentFill until
        // the real favicon stream lands.
        item.IconSource = new Microsoft.UI.Xaml.Controls.SymbolIconSource
        {
            Symbol = Symbol.Globe,
        };

        _tabs[item] = content;
        TabStrip.TabItems.Add(item);
        TabStrip.SelectedItem = item;
    }

    private void OnAddTab(TabView sender, object args)
    {
        CreateTab(new Uri("https://example.com/"));
    }

    private void OnTabClose(TabView sender, TabViewTabCloseRequestedEventArgs args)
    {
        _tabs.Remove(args.Tab);
        sender.TabItems.Remove(args.Tab);
        if (sender.TabItems.Count == 0)
        {
            // No tabs = close window. The App shuts down when the last
            // window exits (single-window process today).
            Close();
        }
    }

    private void OnTabSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (TabStrip.SelectedItem is TabViewItem item &&
            _tabs.TryGetValue(item, out var browserTab))
        {
            ActiveTabHost.Content = browserTab;
        }
        else
        {
            ActiveTabHost.Content = null;
        }
    }
}
