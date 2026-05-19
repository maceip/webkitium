using Microsoft.UI;
using Microsoft.UI.Composition;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Hosting;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Windowing;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Webkitium.FFI;
using Windows.System;
using WinRT.Interop;

namespace Webkitium;

/// <summary>
/// Single browser window. Hosts a TabView whose items each own a WKView
/// (WebKit-for-Windows) embedded via webkitium_host.dll.
/// </summary>
public sealed partial class MainWindow : Window
{
    private const string DefaultEngineId = "duckduckgo";
    private readonly SuggestionsIndex? _suggestions;
    private readonly Dictionary<TabViewItem, BrowserTab> _tabs = new();
    private readonly Microsoft.UI.Xaml.DispatcherTimer _chromeRefreshTimer;
    private bool _suppressUrlBarFeedback;
    private bool _findOverlayOpen;
    private int _findMatchTotal;
    private int _findMatchActive;

    public MainWindow()
    {
        InitializeComponent();
        ResizeTo(1200, 800);

        try
        {
            var profileDir = ResolveProfileDir();
            Directory.CreateDirectory(profileDir);
            var dbPath = Path.Combine(profileDir, "suggestions.db");
            _suggestions = SuggestionsIndex.Open(dbPath);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"SuggestionsIndex.Open failed: {ex}");
            _suggestions = null;
        }

        Closed += (_, _) => _suggestions?.Dispose();

        _chromeRefreshTimer = new Microsoft.UI.Xaml.DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(400),
        };
        _chromeRefreshTimer.Tick += (_, _) => RefreshChromeForCurrentTab();
        _chromeRefreshTimer.Start();

        _ = OpenInitialTabAsync();
        RefreshBookmarksBar();
    }

    private void ResizeTo(int width, int height)
    {
        var hwnd = WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(hwnd);
        var appWindow = AppWindow.GetFromWindowId(windowId);
        appWindow.Resize(new Windows.Graphics.SizeInt32(width, height));
    }

    private static string ResolveProfileDir()
    {
        var args = Environment.GetCommandLineArgs();
        foreach (var a in args.Skip(1))
        {
            const string Flag = "--profile-dir=";
            if (a.StartsWith(Flag, StringComparison.OrdinalIgnoreCase))
                return a.Substring(Flag.Length);
        }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Webkitium");
    }

    private sealed class BrowserTab
    {
        public TabViewItem Item { get; }
        public WebKitViewHost WebView { get; }
        public bool CoreReady { get; private set; }
        public string CurrentUrl { get; private set; } = string.Empty;
        public Action<BrowserTab>? OnNavigated;

        public BrowserTab(TabViewItem item, WebKitViewHost webView)
        {
            Item = item;
            WebView = webView;
        }

        public async Task EnsureCoreAsync()
        {
            if (CoreReady) return;
            for (var i = 0; i < 80 && !WebView.IsReady; i++)
            {
                WebView.SyncNativeFrame();
                await Task.Delay(50);
            }
            CoreReady = WebView.IsReady;
        }

        public void RefreshFromWebKit()
        {
            if (!CoreReady) return;
            var url = WebView.CurrentUrl;
            if (!string.IsNullOrEmpty(url))
                CurrentUrl = url;
            OnNavigated?.Invoke(this);
        }
    }

    private async Task OpenInitialTabAsync()
    {
        var tab = await CreateTabAsync(activate: true);
        var launchUrl = Environment.GetEnvironmentVariable("WEBKITIUM_LAUNCH_URL");
        if (!string.IsNullOrEmpty(launchUrl) && tab.CoreReady)
        {
            try
            {
                var (_, url) = UrlBridge.Normalize(launchUrl, DefaultEngineId);
                tab.WebView.LoadUrl(url);
            }
            catch (ArgumentException) { }
        }
    }

    private async Task<BrowserTab> CreateTabAsync(bool activate)
    {
        var web = new WebKitViewHost(this);
        var item = new TabViewItem
        {
            Header = "New Tab",
            IconSource = new SymbolIconSource { Symbol = Symbol.World },
            Content = web,
            IsClosable = true,
        };
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(item, "Close tab");
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetHelpText(item, "New Tab");

        var bt = new BrowserTab(item, web);
        bt.OnNavigated = OnTabNavigated;
        _tabs[item] = bt;
        Tabs.TabItems.Add(item);
        if (activate) Tabs.SelectedItem = item;
        try
        {
            await bt.EnsureCoreAsync();
        }
        catch (Exception ex)
        {
            item.Header = "WebKit unavailable";
            System.Diagnostics.Debug.WriteLine($"WKView init failed: {ex}");
        }
        if (activate && bt.CoreReady)
            web.SetVisible(true);
        return bt;
    }

    private BrowserTab? CurrentTab =>
        Tabs.SelectedItem is TabViewItem tvi && _tabs.TryGetValue(tvi, out var bt) ? bt : null;

    private void OnTabNavigated(BrowserTab tab)
    {
        if (tab.Item != Tabs.SelectedItem) return;
        RefreshChromeForCurrentTab();
        if (_suggestions is not null && !string.IsNullOrEmpty(tab.CurrentUrl))
        {
            var title = tab.WebView.DocumentTitle;
            tab.Item.Header = string.IsNullOrEmpty(title) ? "Untitled" : title;
            tab.Item.IsClosable = true;
            try { _suggestions.RecordVisit(title, tab.CurrentUrl); } catch { }
        }
    }

    private void Tabs_AddTabButtonClick(TabView sender, object args) =>
        _ = CreateTabAsync(activate: true);

    private void Tabs_TabCloseRequested(TabView sender, TabViewTabCloseRequestedEventArgs args) =>
        CloseTab(args.Tab);

    private void CloseTab(TabViewItem item)
    {
        if (item is null) return;
        if (_tabs.TryGetValue(item, out var bt))
        {
            _tabs.Remove(item);
        }
        Tabs.TabItems.Remove(item);
        if (Tabs.TabItems.Count == 0)
            _ = CreateTabAsync(activate: true);
    }

    private void Tabs_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        foreach (var (_, tab) in _tabs)
            tab.WebView.SetVisible(false);
        if (CurrentTab is { } active)
        {
            active.WebView.SetVisible(true);
            active.WebView.SyncNativeFrame();
            active.RefreshFromWebKit();
        }
        RefreshChromeForCurrentTab();
    }

    private void NewTab_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        _ = CreateTabAsync(activate: true);
    }

    private void CloseTab_Invoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        if (Tabs.SelectedItem is TabViewItem item) CloseTab(item);
    }

    private void RefreshChromeForCurrentTab()
    {
        CurrentTab?.RefreshFromWebKit();
        var tab = CurrentTab;

        BackCommand.IsEnabled = tab?.WebView.CanGoBack ?? false;
        ForwardCommand.IsEnabled = tab?.WebView.CanGoForward ?? false;
        ReloadCommand.IsEnabled = tab?.CoreReady ?? false;

        _suppressUrlBarFeedback = true;
        try { UrlBar.Text = tab?.CurrentUrl ?? string.Empty; }
        finally { _suppressUrlBarFeedback = false; }

        BookmarkButton.Icon = new SymbolIcon(IsCurrentBookmarked() ? Symbol.SolidStar : Symbol.OutlineStar);

        var url = tab?.CurrentUrl;
        var isSecure = !string.IsNullOrEmpty(url)
            && url.StartsWith("https://", StringComparison.OrdinalIgnoreCase);
        SecureLock.Visibility = isSecure ? Visibility.Visible : Visibility.Collapsed;
    }

    private void SecureLock_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement element) return;
        try
        {
            var compositor = ElementCompositionPreview.GetElementVisual(element).Compositor;
            var dropShadow = compositor.CreateDropShadow();
            dropShadow.Color = Windows.UI.Color.FromArgb(0xCC, 0x3B, 0x82, 0xF6);
            dropShadow.BlurRadius = 10.0f;
            dropShadow.Opacity = 0.85f;
            dropShadow.Offset = new System.Numerics.Vector3(0, 0, 0);

            var sprite = compositor.CreateSpriteVisual();
            sprite.Size = new System.Numerics.Vector2(
                (float)element.ActualWidth,
                (float)element.ActualHeight);
            sprite.Shadow = dropShadow;
            ElementCompositionPreview.SetElementChildVisual(element, sprite);

            element.SizeChanged += (_, ev) =>
            {
                sprite.Size = new System.Numerics.Vector2(
                    (float)ev.NewSize.Width,
                    (float)ev.NewSize.Height);
            };
        }
        catch { }
    }

    private void Back_Click(object sender, RoutedEventArgs e) => CurrentTab?.WebView.GoBack();
    private void Forward_Click(object sender, RoutedEventArgs e) => CurrentTab?.WebView.GoForward();
    private void Reload_Click(object sender, RoutedEventArgs e) => CurrentTab?.WebView.Reload();

    private void UrlBar_TextChanged(AutoSuggestBox sender, AutoSuggestBoxTextChangedEventArgs args)
    {
        if (_suppressUrlBarFeedback) return;
        if (args.Reason != AutoSuggestionBoxTextChangeReason.UserInput) return;

        var prefix = sender.Text;
        if (string.IsNullOrWhiteSpace(prefix) || _suggestions is null)
        {
            sender.ItemsSource = null;
            return;
        }

        try
        {
            var hits = _suggestions.Query(prefix, 8);
            sender.ItemsSource = hits.Select(h => new SuggestionViewModel(h)).ToList();
        }
        catch
        {
            sender.ItemsSource = null;
        }
    }

    private void UrlBar_SuggestionChosen(AutoSuggestBox sender, AutoSuggestBoxSuggestionChosenEventArgs args)
    {
        if (args.SelectedItem is SuggestionViewModel vm) sender.Text = vm.NavigateUrl;
    }

    private void UrlBar_QuerySubmitted(AutoSuggestBox sender, AutoSuggestBoxQuerySubmittedEventArgs args)
    {
        var input = args.ChosenSuggestion is SuggestionViewModel vm ? vm.NavigateUrl : sender.Text;
        NavigateCurrentTab(input);
    }

    private void NavigateCurrentTab(string raw)
    {
        var tab = CurrentTab;
        if (tab is null || !tab.CoreReady) return;
        try
        {
            var (_, url) = UrlBridge.Normalize(raw, DefaultEngineId);
            tab.WebView.LoadUrl(url);
            tab.CurrentUrl = url;
            RefreshChromeForCurrentTab();
        }
        catch (ArgumentException) { }
    }

    private sealed class SuggestionViewModel
    {
        public string Title { get; }
        public string Subtitle { get; }
        public string NavigateUrl { get; }
        public SuggestionViewModel(Suggestion s)
        {
            Title = string.IsNullOrEmpty(s.Title) ? s.Subtitle : s.Title;
            Subtitle = s.Subtitle;
            NavigateUrl = s.Subtitle;
        }
        public override string ToString() => Title;
    }

    private bool IsCurrentBookmarked()
    {
        if (_suggestions is null) return false;
        var url = CurrentTab?.CurrentUrl;
        if (string.IsNullOrEmpty(url)) return false;
        try { return _suggestions.IsBookmarked(url); }
        catch { return false; }
    }

    private void BookmarkButton_Click(object sender, RoutedEventArgs e)
    {
        var tab = CurrentTab;
        if (_suggestions is null || tab is null || string.IsNullOrEmpty(tab.CurrentUrl)) return;

        bool wasBookmarked = _suggestions.IsBookmarked(tab.CurrentUrl);
        _suggestions.SetBookmarked(tab.CurrentUrl, !wasBookmarked);
        BookmarkButton.Icon = new SymbolIcon((!wasBookmarked) ? Symbol.SolidStar : Symbol.OutlineStar);
        RefreshBookmarksBar();
    }

    private void RefreshBookmarksBar()
    {
        if (_suggestions is null) { BookmarksRepeater.ItemsSource = null; return; }
        try
        {
            var rows = _suggestions.BookmarksFlat(16);
            BookmarksRepeater.ItemTemplate = BuildBookmarkTemplate();
            BookmarksRepeater.ItemsSource = rows.Select(r => new BookmarkButtonViewModel(r, OnBookmarkClicked)).ToList();
        }
        catch
        {
            BookmarksRepeater.ItemsSource = null;
        }
    }

    private static DataTemplate BuildBookmarkTemplate()
    {
        var xaml = """
            <DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                          xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
                <Button Padding="6,2,6,2"
                        Background="{ThemeResource SubtleFillColorTransparentBrush}"
                        Content="{Binding Title}"
                        Command="{Binding ClickCommand}" />
            </DataTemplate>
            """;
        return (DataTemplate)Microsoft.UI.Xaml.Markup.XamlReader.Load(xaml);
    }

    private void OnBookmarkClicked(BookmarkButtonViewModel vm) => NavigateCurrentTab(vm.Url);

    private sealed class BookmarkButtonViewModel
    {
        public string Title { get; }
        public string Url { get; }
        public RelayCommand ClickCommand { get; }
        public BookmarkButtonViewModel(BookmarkRow row, Action<BookmarkButtonViewModel> onClick)
        {
            Title = string.IsNullOrEmpty(row.Title) ? row.Url : row.Title;
            Url = row.Url;
            ClickCommand = new RelayCommand(_ => onClick(this));
        }
    }

    private sealed class RelayCommand : System.Windows.Input.ICommand
    {
        private readonly Action<object?> _action;
        public RelayCommand(Action<object?> action) { _action = action; }
        public event EventHandler? CanExecuteChanged { add { } remove { } }
        public bool CanExecute(object? parameter) => true;
        public void Execute(object? parameter) => _action(parameter);
    }

    private void Find_Click(object sender, RoutedEventArgs e) => OpenFindOverlay();

    private void OpenFindOverlay()
    {
        _findOverlayOpen = true;
        FindOverlay.Visibility = Visibility.Visible;
        FindBox.Focus(FocusState.Programmatic);
        FindBox.SelectAll();
    }

    private void CloseFindOverlay()
    {
        _findOverlayOpen = false;
        FindOverlay.Visibility = Visibility.Collapsed;
        ClearHighlights();
    }

    private void FindBox_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Escape) { e.Handled = true; CloseFindOverlay(); return; }
        if (e.Key == VirtualKey.Enter)
        {
            e.Handled = true;
            MoveFind(forward: true);
        }
    }

    private void FindBox_TextChanged(object sender, TextChangedEventArgs e) =>
        ExecuteFind(FindBox.Text);

    private void FindNext_Click(object sender, RoutedEventArgs e) => MoveFind(forward: true);
    private void FindPrev_Click(object sender, RoutedEventArgs e) => MoveFind(forward: false);
    private void FindClose_Click(object sender, RoutedEventArgs e) => CloseFindOverlay();

    private const string FindControllerJs = """
        (() => {
          if (window.__wkFind) return window.__wkFind;
          const NS = '__wkFind';
          window[NS] = {
            matches: [],
            active: 0,
            clear() {
              for (const m of document.querySelectorAll('mark[data-wk-find]')) {
                const t = document.createTextNode(m.textContent || '');
                m.replaceWith(t);
              }
              this.matches = [];
              this.active = 0;
            },
            search(q) {
              this.clear();
              if (!q) return JSON.stringify({ total: 0, active: 0 });
              const re = new RegExp(q.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'gi');
              const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
                acceptNode: (n) => (n.parentNode && n.parentNode.nodeName !== 'SCRIPT' && n.parentNode.nodeName !== 'STYLE') ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT
              });
              const nodes = [];
              let n; while ((n = walker.nextNode())) nodes.push(n);
              for (const node of nodes) {
                const s = node.nodeValue || '';
                if (!re.test(s)) { re.lastIndex = 0; continue; }
                re.lastIndex = 0;
                const frag = document.createDocumentFragment();
                let last = 0, m;
                while ((m = re.exec(s)) !== null) {
                  if (m.index > last) frag.appendChild(document.createTextNode(s.slice(last, m.index)));
                  const mark = document.createElement('mark');
                  mark.setAttribute('data-wk-find', String(this.matches.length));
                  mark.style.background = '#ffe066';
                  mark.textContent = m[0];
                  frag.appendChild(mark);
                  this.matches.push(mark);
                  last = re.lastIndex;
                  if (m.index === re.lastIndex) re.lastIndex++;
                }
                if (last < s.length) frag.appendChild(document.createTextNode(s.slice(last)));
                node.parentNode.replaceChild(frag, node);
              }
              this.active = this.matches.length > 0 ? 0 : -1;
              this._highlight();
              return JSON.stringify({ total: this.matches.length, active: this.matches.length > 0 ? 1 : 0 });
            },
            move(forward) {
              if (!this.matches.length) return JSON.stringify({ total: 0, active: 0 });
              this.active = forward
                ? (this.active + 1) % this.matches.length
                : (this.active - 1 + this.matches.length) % this.matches.length;
              this._highlight();
              return JSON.stringify({ total: this.matches.length, active: this.active + 1 });
            },
            _highlight() {
              this.matches.forEach((m, i) => m.style.outline = (i === this.active) ? '2px solid #f08c00' : 'none');
              if (this.active >= 0 && this.matches[this.active])
                this.matches[this.active].scrollIntoView({ block: 'center' });
            }
          };
          return window[NS];
        })();
        """;

    private void ExecuteFind(string query)
    {
        var tab = CurrentTab;
        if (tab is null || !tab.CoreReady) return;
        var quoted = System.Text.Json.JsonSerializer.Serialize(query);
        var script = FindControllerJs + "\nwindow.__wkFind.search(" + quoted + ");";
        var result = tab.WebView.RunScript(script);
        ApplyFindResult(result);
    }

    private void MoveFind(bool forward)
    {
        var tab = CurrentTab;
        if (tab is null || !tab.CoreReady) return;
        var script = FindControllerJs + $"\nwindow.__wkFind.move({(forward ? "true" : "false")});";
        var result = tab.WebView.RunScript(script);
        ApplyFindResult(result);
    }

    private void ClearHighlights()
    {
        var tab = CurrentTab;
        if (tab is null || !tab.CoreReady) return;
        tab.WebView.RunScript("if (window.__wkFind) window.__wkFind.clear();");
        _findMatchActive = 0;
        _findMatchTotal = 0;
        FindMatchCount.Text = "0/0";
    }

    private void ApplyFindResult(string? jsonReturn)
    {
        if (string.IsNullOrEmpty(jsonReturn))
        {
            FindMatchCount.Text = "?/?";
            return;
        }
        try
        {
            using var doc = System.Text.Json.JsonDocument.Parse(jsonReturn);
            _findMatchTotal = doc.RootElement.GetProperty("total").GetInt32();
            _findMatchActive = doc.RootElement.GetProperty("active").GetInt32();
            FindMatchCount.Text = $"{_findMatchActive}/{_findMatchTotal}";
        }
        catch
        {
            FindMatchCount.Text = "?/?";
        }
    }
}
