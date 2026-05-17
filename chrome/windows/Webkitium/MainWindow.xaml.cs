using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Windowing;
using Microsoft.Web.WebView2.Core;
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
/// Single browser window. Hosts a TabView whose items each own their own
/// WebView2. The chrome (URL bar, back/forward/reload, bookmark star,
/// find overlay) acts on the *currently selected* tab.
/// </summary>
public sealed partial class MainWindow : Window
{
    private const string DefaultEngineId = "duckduckgo";
    private readonly SuggestionsIndex? _suggestions;
    private readonly Dictionary<TabViewItem, BrowserTab> _tabs = new();
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
            // Non-fatal: autocomplete and bookmark persistence fall back to empty.
            System.Diagnostics.Debug.WriteLine($"SuggestionsIndex.Open failed: {ex}");
            _suggestions = null;
        }

        Closed += (_, _) => _suggestions?.Dispose();

        _ = OpenInitialTabAsync();
        RefreshBookmarksBar();
    }

    // --------------------- Window plumbing ---------------------

    private void ResizeTo(int width, int height)
    {
        var hwnd = WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(hwnd);
        var appWindow = AppWindow.GetFromWindowId(windowId);
        appWindow.Resize(new Windows.Graphics.SizeInt32(width, height));
    }

    /// <summary>
    /// Profile directory comes from `--profile-dir=<path>` if the harness
    /// passed it; otherwise %LocalAppData%\Webkitium.
    /// </summary>
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

    // --------------------- Tab management ---------------------

    /// <summary>One tab + one WebView2; lives until the tab is closed.</summary>
    private sealed class BrowserTab
    {
        public TabViewItem Item { get; }
        public WebView2 WebView { get; }
        public bool CoreReady { get; private set; }
        public string CurrentUrl { get; private set; } = string.Empty;
        public Action<BrowserTab>? OnNavigated;

        public BrowserTab(TabViewItem item, WebView2 webView)
        {
            Item = item;
            WebView = webView;
        }

        public async Task EnsureCoreAsync()
        {
            if (CoreReady) return;
            await WebView.EnsureCoreWebView2Async();
            CoreReady = true;
            WebView.CoreWebView2.HistoryChanged += (_, _) => OnNavigated?.Invoke(this);
            WebView.NavigationCompleted += (s, args) =>
            {
                if (args.IsSuccess && s.Source is { } uri)
                    CurrentUrl = uri.ToString();
                OnNavigated?.Invoke(this);
            };
        }
    }

    private async Task OpenInitialTabAsync()
    {
        var tab = await CreateTabAsync(activate: true);
        // Leave the new tab on its blank state — user types into URL bar.
        _ = tab;
    }

    private async Task<BrowserTab> CreateTabAsync(bool activate)
    {
        var web = new WebView2();
        var item = new TabViewItem
        {
            Header = "New Tab",
            IconSource = new Microsoft.UI.Xaml.Controls.SymbolIconSource { Symbol = Symbol.World },
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
            item.Header = "WebView2 unavailable";
            System.Diagnostics.Debug.WriteLine($"WebView2 init failed: {ex}");
        }
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
            // Record visit (page title is the WebView's CoreWebView2.DocumentTitle).
            var title = tab.WebView.CoreWebView2?.DocumentTitle ?? string.Empty;
            tab.Item.Header = string.IsNullOrEmpty(title) ? "Untitled" : title;
            tab.Item.IsClosable = true;
            try { _suggestions.RecordVisit(title, tab.CurrentUrl); } catch { }
        }
    }

    private void Tabs_AddTabButtonClick(TabView sender, object args) =>
        _ = CreateTabAsync(activate: true);

    private void Tabs_TabCloseRequested(TabView sender, TabViewTabCloseRequestedEventArgs args)
    {
        CloseTab(args.Tab);
    }

    private void CloseTab(TabViewItem item)
    {
        if (item is null) return;
        if (_tabs.TryGetValue(item, out var bt))
        {
            bt.WebView.Close();
            _tabs.Remove(item);
        }
        Tabs.TabItems.Remove(item);
        if (Tabs.TabItems.Count == 0)
        {
            _ = CreateTabAsync(activate: true);
        }
    }

    private void Tabs_SelectionChanged(object sender, SelectionChangedEventArgs e) =>
        RefreshChromeForCurrentTab();

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

    // --------------------- Chrome (URL bar / back-forward / bookmark) ---------------------

    private void RefreshChromeForCurrentTab()
    {
        var tab = CurrentTab;
        var core = tab?.WebView.CoreWebView2;

        BackCommand.IsEnabled = core?.CanGoBack ?? false;
        ForwardCommand.IsEnabled = core?.CanGoForward ?? false;
        ReloadCommand.IsEnabled = core is not null;

        _suppressUrlBarFeedback = true;
        try { UrlBar.Text = tab?.CurrentUrl ?? string.Empty; }
        finally { _suppressUrlBarFeedback = false; }

        BookmarkButton.Icon = new SymbolIcon(IsCurrentBookmarked() ? Symbol.SolidStar : Symbol.OutlineStar);
    }

    private void Back_Click(object sender, RoutedEventArgs e) =>
        CurrentTab?.WebView.CoreWebView2?.GoBack();
    private void Forward_Click(object sender, RoutedEventArgs e) =>
        CurrentTab?.WebView.CoreWebView2?.GoForward();
    private void Reload_Click(object sender, RoutedEventArgs e) =>
        CurrentTab?.WebView.CoreWebView2?.Reload();

    // --------------------- URL bar (autocomplete + submit) ---------------------

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
            tab.WebView.Source = new Uri(url);
        }
        catch (ArgumentException) { /* empty / invalid input */ }
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

    // --------------------- Bookmarks ---------------------

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
        // Code-generated template: a Button per bookmark.
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

    // --------------------- Find on page ---------------------

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
        _ = ClearHighlightsAsync();
    }

    private void FindBox_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Escape) { e.Handled = true; CloseFindOverlay(); return; }
        if (e.Key == VirtualKey.Enter)
        {
            e.Handled = true;
            _ = MoveFindAsync(forward: true);
        }
    }

    private void FindBox_TextChanged(object sender, TextChangedEventArgs e) =>
        _ = ExecuteFindAsync(FindBox.Text);

    private void FindNext_Click(object sender, RoutedEventArgs e) => _ = MoveFindAsync(forward: true);
    private void FindPrev_Click(object sender, RoutedEventArgs e) => _ = MoveFindAsync(forward: false);
    private void FindClose_Click(object sender, RoutedEventArgs e) => CloseFindOverlay();

    // Canonical WebView2-doesn't-have-Find pattern: inject a small JS find
    // controller into the active document. Walks text nodes, wraps matches
    // in <mark data-wk-find="i">, scrolls to active, returns counts.
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
              if (!q) return { total: 0, active: 0 };
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
                  mark.style.color = 'inherit';
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
              return { total: this.matches.length, active: this.matches.length > 0 ? 1 : 0 };
            },
            move(forward) {
              if (!this.matches.length) return { total: 0, active: 0 };
              this.active = forward
                ? (this.active + 1) % this.matches.length
                : (this.active - 1 + this.matches.length) % this.matches.length;
              this._highlight();
              return { total: this.matches.length, active: this.active + 1 };
            },
            _highlight() {
              this.matches.forEach((m, i) => m.style.outline = (i === this.active) ? '2px solid #f08c00' : 'none');
              if (this.active >= 0 && this.matches[this.active]) {
                this.matches[this.active].scrollIntoView({ block: 'center' });
              }
            }
          };
          return window[NS];
        })();
        """;

    private async Task ExecuteFindAsync(string query)
    {
        var core = CurrentTab?.WebView.CoreWebView2;
        if (core is null) return;
        var quoted = System.Text.Json.JsonSerializer.Serialize(query);
        var script = FindControllerJs + "\nJSON.stringify(window.__wkFind.search(" + quoted + "));";
        var result = await core.ExecuteScriptAsync(script);
        ApplyFindResult(result);
    }

    private async Task MoveFindAsync(bool forward)
    {
        var core = CurrentTab?.WebView.CoreWebView2;
        if (core is null) return;
        var script = FindControllerJs + $"\nJSON.stringify(window.__wkFind.move({(forward ? "true" : "false")}));";
        var result = await core.ExecuteScriptAsync(script);
        ApplyFindResult(result);
    }

    private async Task ClearHighlightsAsync()
    {
        var core = CurrentTab?.WebView.CoreWebView2;
        if (core is null) return;
        await core.ExecuteScriptAsync("if (window.__wkFind) window.__wkFind.clear();");
        _findMatchActive = 0;
        _findMatchTotal = 0;
        FindMatchCount.Text = "0/0";
    }

    private void ApplyFindResult(string jsonReturn)
    {
        // ExecuteScriptAsync wraps its return in JSON, so the value is a JSON
        // string containing a JSON object. Parse twice.
        try
        {
            var inner = System.Text.Json.JsonSerializer.Deserialize<string>(jsonReturn);
            if (inner is null) return;
            using var doc = System.Text.Json.JsonDocument.Parse(inner);
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
