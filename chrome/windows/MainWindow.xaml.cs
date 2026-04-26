using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Web.WebView2.Core;
using Webkitium.Views;
using Windows.System;
using WinUIEx;

namespace Webkitium;

public sealed partial class MainWindow : WindowEx
{
    private readonly Dictionary<TabViewItem, BrowserTab> _tabs = new();
    private readonly Stack<(string url, string title)> _closedTabStack = new();
    private FindBar? _findBar;

    public MainWindow()
    {
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(TitleBarStrip);

        Omnibar.Submitted += (_, text) =>
        {
            if (ActiveBrowserTab is { } tab)
                tab.Navigate(NormalizeUrl(text));
        };

        RegisterAccelerators();
        CreateTab(new Uri("https://example.com/"));
    }

    private BrowserTab? ActiveBrowserTab
    {
        get
        {
            if (TabStrip.SelectedItem is TabViewItem item &&
                _tabs.TryGetValue(item, out var tab))
                return tab;
            return null;
        }
    }

    private TabViewItem? TabItemForBrowserTab(BrowserTab bt)
        => _tabs.FirstOrDefault(kv => kv.Value == bt).Key;

    // -- Accelerators (Tier 1 + Tier 2) --

    private void RegisterAccelerators()
    {
        // Ctrl+T: new tab
        AddAccelerator(VirtualKey.T, VirtualKeyModifiers.Control,
            (_, _) => CreateTab(new Uri("https://example.com/")));
        // Ctrl+W: close tab
        AddAccelerator(VirtualKey.W, VirtualKeyModifiers.Control,
            (_, _) => CloseActiveTab());
        // Ctrl+Shift+T: restore closed tab
        AddAccelerator(VirtualKey.T, VirtualKeyModifiers.Control | VirtualKeyModifiers.Shift,
            (_, _) => RestoreClosedTab());
        // Ctrl+R / F5: reload
        AddAccelerator(VirtualKey.R, VirtualKeyModifiers.Control,
            (_, _) => ActiveBrowserTab?.Reload());
        AddAccelerator(VirtualKey.F5, VirtualKeyModifiers.None,
            (_, _) => ActiveBrowserTab?.Reload());
        // Alt+Left: back
        AddAccelerator(VirtualKey.Left, VirtualKeyModifiers.Menu,
            (_, _) => ActiveBrowserTab?.GoBack());
        // Alt+Right: forward
        AddAccelerator(VirtualKey.Right, VirtualKeyModifiers.Menu,
            (_, _) => ActiveBrowserTab?.GoForward());
        // Ctrl+F: find in page
        AddAccelerator(VirtualKey.F, VirtualKeyModifiers.Control,
            (_, _) => ShowFindBar());
        // F12: DevTools
        AddAccelerator(VirtualKey.F12, VirtualKeyModifiers.None,
            (_, _) => ActiveBrowserTab?.OpenDevTools());
        // Ctrl+P: print
        AddAccelerator(VirtualKey.P, VirtualKeyModifiers.Control,
            (_, _) => ActiveBrowserTab?.PrintToPdf());
        // Ctrl+Plus: zoom in
        AddAccelerator((VirtualKey)0xBB, VirtualKeyModifiers.Control,
            (_, _) => ZoomActive(0.1));
        // Ctrl+Minus: zoom out
        AddAccelerator((VirtualKey)0xBD, VirtualKeyModifiers.Control,
            (_, _) => ZoomActive(-0.1));
        // Ctrl+0: zoom reset
        AddAccelerator(VirtualKey.Number0, VirtualKeyModifiers.Control,
            (_, _) => { if (ActiveBrowserTab is { } t) t.SetZoom(1.0); });
        // Ctrl+D: bookmark
        AddAccelerator(VirtualKey.D, VirtualKeyModifiers.Control,
            (_, _) => BookmarkActiveTab());
        // Ctrl+,: settings
        AddAccelerator((VirtualKey)0xBC, VirtualKeyModifiers.Control,
            (_, _) => App.Current.OpenSettings());
        // Escape: dismiss find bar
        AddAccelerator(VirtualKey.Escape, VirtualKeyModifiers.None,
            (_, _) => HideFindBar());
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
            root.KeyboardAccelerators.Add(accel);
    }

    // -- Tab lifecycle (Tier 1) --

    private void CreateTab(Uri initialUrl)
    {
        var content = new BrowserTab { InitialSource = initialUrl };
        var item = new TabViewItem
        {
            Header = "New Tab",
            IsClosable = true,
        };
        item.IconSource = new SymbolIconSource { Symbol = Symbol.Globe };

        content.TitleChanged += (_, title) =>
        {
            if (TabItemForBrowserTab(content) is { } tabItem)
                tabItem.Header = string.IsNullOrEmpty(title) ? "New Tab" : title;
        };

        content.NavigationCompleted += (_, args) =>
        {
            if (!args.IsSuccess)
                content.LoadErrorPage(
                    content.InitialSource?.AbsoluteUri ?? "",
                    $"Navigation failed: {args.WebErrorStatus}");
        };

        content.DownloadStarting += OnDownloadStarting;
        content.PermissionRequested += OnPermissionRequested;
        content.NewWindowRequested += (_, args) =>
        {
            args.Handled = true;
            if (Uri.TryCreate(args.Uri, UriKind.Absolute, out var uri))
                CreateTab(uri);
        };

        _tabs[item] = content;
        TabStrip.TabItems.Add(item);
        TabStrip.SelectedItem = item;
    }

    private void CloseActiveTab()
    {
        if (TabStrip.SelectedItem is not TabViewItem item) return;
        if (_tabs.TryGetValue(item, out var bt))
        {
            _closedTabStack.Push((bt.InitialSource?.AbsoluteUri ?? "https://example.com/", (string)(item.Header ?? "")));
            _tabs.Remove(item);
        }
        TabStrip.TabItems.Remove(item);
        if (TabStrip.TabItems.Count == 0)
            Close();
    }

    private void RestoreClosedTab()
    {
        if (_closedTabStack.Count == 0) return;
        var (url, _) = _closedTabStack.Pop();
        CreateTab(Uri.TryCreate(url, UriKind.Absolute, out var uri) ? uri : new Uri("https://example.com/"));
    }

    private void OnAddTab(TabView sender, object args)
        => CreateTab(new Uri("https://example.com/"));

    private void OnTabClose(TabView sender, TabViewTabCloseRequestedEventArgs args)
    {
        if (_tabs.TryGetValue(args.Tab, out var bt))
        {
            _closedTabStack.Push((bt.InitialSource?.AbsoluteUri ?? "", (string)(args.Tab.Header ?? "")));
            _tabs.Remove(args.Tab);
        }
        sender.TabItems.Remove(args.Tab);
        if (sender.TabItems.Count == 0)
            Close();
    }

    private void OnTabSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        ActiveTabHost.Content = ActiveBrowserTab;
    }

    // -- Zoom (Tier 2) --

    private void ZoomActive(double delta)
    {
        if (ActiveBrowserTab is not { } tab) return;
        var z = Math.Clamp(tab.GetZoom() + delta, 0.25, 5.0);
        tab.SetZoom(z);
    }

    // -- Find-in-page (Tier 2) --

    private void ShowFindBar()
    {
        if (_findBar is not null) return;
        _findBar = new FindBar();
        _findBar.QuerySubmitted += (_, query) => ActiveBrowserTab?.FindInPage(query);
        _findBar.Closed += (_, _) => HideFindBar();
        if (Content is Grid grid && grid.RowDefinitions.Count >= 2)
        {
            Grid.SetRow(_findBar, 0);
            Grid.SetColumnSpan(_findBar, 4);
            _findBar.HorizontalAlignment = HorizontalAlignment.Right;
            _findBar.VerticalAlignment = VerticalAlignment.Bottom;
            _findBar.Margin = new Thickness(0, 0, 160, 0);
            grid.Children.Add(_findBar);
        }
    }

    private void HideFindBar()
    {
        if (_findBar is null) return;
        ActiveBrowserTab?.DismissFind();
        if (Content is Grid grid)
            grid.Children.Remove(_findBar);
        _findBar = null;
    }

    // -- Bookmarks (Tier 2) --

    private void BookmarkActiveTab()
    {
        // Placeholder: shows a flyout confirming bookmark saved.
        if (ActiveBrowserTab is not { } tab) return;
        var flyout = new Flyout
        {
            Content = new TextBlock
            {
                Text = "Bookmark saved!",
                FontSize = 14,
                Padding = new Thickness(8),
            }
        };
        flyout.ShowAt(Omnibar);
    }

    // -- Downloads (Tier 2) --

    private void OnDownloadStarting(object? sender, CoreWebView2DownloadStartingEventArgs args)
    {
        // Let WebView2 handle the download with its default UI for now.
        // The download item is tracked by the CoreWebView2 itself.
    }

    // -- Permissions (Tier 2) --

    private void OnPermissionRequested(object? sender, CoreWebView2PermissionRequestedEventArgs args)
    {
        var deferral = args.GetDeferral();
        DispatcherQueue.TryEnqueue(async () =>
        {
            var dialog = new ContentDialog
            {
                Title = "Permission Request",
                Content = $"This site wants to access your {args.PermissionKind}.",
                PrimaryButtonText = "Allow",
                SecondaryButtonText = "Deny",
                CloseButtonText = "Dismiss",
                XamlRoot = Content.XamlRoot,
            };

            var result = await dialog.ShowAsync();
            args.State = result switch
            {
                ContentDialogResult.Primary => CoreWebView2PermissionState.Allow,
                ContentDialogResult.Secondary => CoreWebView2PermissionState.Deny,
                _ => CoreWebView2PermissionState.Default,
            };
            deferral.Complete();
        });
    }

    // -- URL normalization --

    private static Uri NormalizeUrl(string text)
    {
        var trimmed = text.Trim();
        if (Uri.TryCreate(trimmed, UriKind.Absolute, out var direct)) return direct;
        if (trimmed.Contains('.') && !trimmed.Contains(' '))
        {
            if (Uri.TryCreate("https://" + trimmed, UriKind.Absolute, out var asHttps)) return asHttps;
        }
        return new Uri("https://duckduckgo.com/?q=" + Uri.EscapeDataString(trimmed));
    }
}
