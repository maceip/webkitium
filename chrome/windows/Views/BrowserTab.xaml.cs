using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Web.WebView2.Core;

namespace Webkitium.Views;

public sealed partial class BrowserTab : UserControl
{
    private bool _initialized;

    public event EventHandler<string>? TitleChanged;
    public event EventHandler<Uri>? FaviconChanged;
    public event EventHandler<bool>? LoadingChanged;
    public event EventHandler<CoreWebView2NavigationCompletedEventArgs>? NavigationCompleted;
    public event EventHandler<CoreWebView2NewWindowRequestedEventArgs>? NewWindowRequested;
    public event EventHandler<CoreWebView2DownloadStartingEventArgs>? DownloadStarting;
    public event EventHandler<CoreWebView2PermissionRequestedEventArgs>? PermissionRequested;
    public event EventHandler<CoreWebView2ContextMenuRequestedEventArgs>? ContextMenuRequested;

    public bool CanGoBack => _initialized && PART_WebView.CoreWebView2?.CanGoBack == true;
    public bool CanGoForward => _initialized && PART_WebView.CoreWebView2?.CanGoForward == true;

    public BrowserTab()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (_initialized) return;
        await PART_WebView.EnsureCoreWebView2Async();
        _initialized = true;

        var coreWv = PART_WebView.CoreWebView2;
        if (coreWv == null) return;

        var settings = coreWv.Settings;
        settings.AreDevToolsEnabled = true;
        settings.AreDefaultContextMenusEnabled = true;
        settings.IsZoomControlEnabled = true;
        settings.IsStatusBarEnabled = true;

        coreWv.DocumentTitleChanged += (_, _) =>
            TitleChanged?.Invoke(this, coreWv.DocumentTitle ?? "");

        coreWv.FaviconChanged += (_, _) =>
        {
            var faviconUri = coreWv.FaviconUri;
            if (!string.IsNullOrEmpty(faviconUri) && Uri.TryCreate(faviconUri, UriKind.Absolute, out var uri))
                FaviconChanged?.Invoke(this, uri);
        };

        coreWv.NavigationStarting += (_, _) => LoadingChanged?.Invoke(this, true);
        coreWv.NavigationCompleted += (_, args) =>
        {
            LoadingChanged?.Invoke(this, false);
            NavigationCompleted?.Invoke(this, args);
        };
        coreWv.NewWindowRequested += (_, args) => NewWindowRequested?.Invoke(this, args);
        coreWv.DownloadStarting += (_, args) => DownloadStarting?.Invoke(this, args);
        coreWv.PermissionRequested += (_, args) => PermissionRequested?.Invoke(this, args);
        coreWv.ContextMenuRequested += (_, args) => ContextMenuRequested?.Invoke(this, args);

        if (_pendingSource is not null)
        {
            coreWv.Navigate(_pendingSource.AbsoluteUri);
            _pendingSource = null;
        }
    }

    public void Navigate(Uri url)
    {
        if (_initialized && PART_WebView.CoreWebView2 is not null)
            PART_WebView.CoreWebView2.Navigate(url.AbsoluteUri);
        else
            _pendingSource = url;
    }

    private Uri? _pendingSource;

    public Uri? InitialSource
    {
        get => PART_WebView.Source;
        set
        {
            if (value is null) return;
            if (_initialized && PART_WebView.CoreWebView2 is not null)
                PART_WebView.CoreWebView2.Navigate(value.AbsoluteUri);
            else
                _pendingSource = value;
        }
    }

    public void GoBack() { if (CanGoBack) PART_WebView.CoreWebView2!.GoBack(); }
    public void GoForward() { if (CanGoForward) PART_WebView.CoreWebView2!.GoForward(); }
    public void Reload() { PART_WebView.CoreWebView2?.Reload(); }
    public void StopLoading() { PART_WebView.CoreWebView2?.Stop(); }

    public void OpenDevTools() { PART_WebView.CoreWebView2?.OpenDevToolsWindow(); }

    private double _zoomFactor = 1.0;

    public void SetZoom(double factor)
    {
        _zoomFactor = factor;
        PART_WebView.CoreWebView2?.ExecuteScriptAsync(
            $"document.body.style.zoom = '{factor * 100}%'");
    }

    public double GetZoom() => _zoomFactor;

    public void FindInPage(string query, bool forward = true)
    {
        // WebView2 exposes find via ICoreWebView2_17.FindController;
        // if not available, execute JavaScript-based find.
        PART_WebView.CoreWebView2?.ExecuteScriptAsync(
            $"window.find('{EscapeJs(query)}', false, {(forward ? "false" : "true")}, true)");
    }

    public void DismissFind()
    {
        PART_WebView.CoreWebView2?.ExecuteScriptAsync("window.getSelection().removeAllRanges()");
    }

    public async void PrintToPdf()
    {
        if (PART_WebView.CoreWebView2 is null) return;
        var picker = new Windows.Storage.Pickers.FileSavePicker();
        picker.SuggestedStartLocation = Windows.Storage.Pickers.PickerLocationId.DocumentsLibrary;
        picker.FileTypeChoices.Add("PDF", new[] { ".pdf" });
        picker.SuggestedFileName = PART_WebView.CoreWebView2.DocumentTitle ?? "page";

        var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.Current.MainWindow);
        WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

        var file = await picker.PickSaveFileAsync();
        if (file is not null)
        {
            var printSettings = PART_WebView.CoreWebView2.Environment.CreatePrintSettings();
            await PART_WebView.CoreWebView2.PrintToPdfAsync(file.Path, printSettings);
        }
    }

    public void LoadErrorPage(string failedUrl, string errorMessage)
    {
        var html = $@"<!DOCTYPE html>
<html><head><meta charset='utf-8'/>
<style>
  body {{ font-family: 'Segoe UI', system-ui, sans-serif; display: flex;
         flex-direction: column; align-items: center; justify-content: center;
         height: 100vh; margin: 0; background: #1a1a2e; color: #e0e0e0; }}
  h1 {{ font-size: 24px; margin-bottom: 8px; color: #ff6b6b; }}
  p {{ font-size: 14px; color: #a0a0a0; max-width: 480px; text-align: center; }}
  code {{ background: #2a2a3e; padding: 2px 6px; border-radius: 4px; }}
  button {{ margin-top: 16px; padding: 8px 24px; border: none;
            border-radius: 6px; background: #4a9eff; color: #fff;
            cursor: pointer; font-size: 14px; }}
  button:hover {{ background: #3a8eef; }}
</style></head><body>
<h1>This page isn't working</h1>
<p><code>{System.Net.WebUtility.HtmlEncode(failedUrl)}</code></p>
<p>{System.Net.WebUtility.HtmlEncode(errorMessage)}</p>
<button onclick=""history.back()"">Go back</button>
</body></html>";
        PART_WebView.CoreWebView2?.NavigateToString(html);
    }

    private static string EscapeJs(string s) =>
        s.Replace("\\", "\\\\").Replace("'", "\\'").Replace("\n", "\\n").Replace("\r", "\\r");
}
