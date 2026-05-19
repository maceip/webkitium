using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Webkitium.FFI;
using Windows.Foundation;
using WinRT.Interop;

namespace Webkitium;

/// <summary>
/// WinUI placeholder that parents a native WKView HWND into the main window,
/// positioned to match this element's bounds on screen.
/// </summary>
public sealed class WebKitViewHost : Grid
{
    private readonly Window _ownerWindow;
    private nint _nativeView;
    private bool _created;

    public WebKitViewHost(Window ownerWindow)
    {
        _ownerWindow = ownerWindow;
        Loaded += (_, _) => EnsureNativeView();
        SizeChanged += (_, _) => UpdateNativeFrame();
        Unloaded += (_, _) => DestroyNativeView();
    }

    public nint NativeViewHandle => _nativeView;
    public bool IsReady => _nativeView != 0;

    public void SetVisible(bool visible)
    {
        if (_nativeView != 0)
            WebKitHostBridge.ViewSetVisible(_nativeView, visible ? 1 : 0);
    }

    public void LoadUrl(string url)
    {
        if (_nativeView != 0)
            WebKitHostBridge.ViewLoadUrl(_nativeView, url);
    }

    public void GoBack()
    {
        if (_nativeView != 0) WebKitHostBridge.ViewGoBack(_nativeView);
    }

    public void GoForward()
    {
        if (_nativeView != 0) WebKitHostBridge.ViewGoForward(_nativeView);
    }

    public void Reload()
    {
        if (_nativeView != 0) WebKitHostBridge.ViewReload(_nativeView);
    }

    public bool CanGoBack => _nativeView != 0 && WebKitHostBridge.ViewCanGoBack(_nativeView) != 0;
    public bool CanGoForward => _nativeView != 0 && WebKitHostBridge.ViewCanGoForward(_nativeView) != 0;

    public string CurrentUrl =>
        _nativeView == 0 ? string.Empty : WebKitHostBridge.CopyUtf8(_nativeView, static (v, b, l) => WebKitHostBridge.ViewCopyUrl(v, b, l));

    public string DocumentTitle =>
        _nativeView == 0 ? string.Empty : WebKitHostBridge.CopyUtf8(_nativeView, static (v, b, l) => WebKitHostBridge.ViewCopyTitle(v, b, l));

    public string? RunScript(string script, uint timeoutMs = 5000)
    {
        if (_nativeView == 0) return null;
        var buf = new byte[65536];
        var written = WebKitHostBridge.ViewRunScript(_nativeView, script, buf, (nuint)buf.Length, timeoutMs);
        if (written == 0) return null;
        var len = Array.IndexOf(buf, (byte)0);
        if (len < 0) len = (int)written;
        return System.Text.Encoding.UTF8.GetString(buf, 0, len);
    }

    private void EnsureNativeView()
    {
        if (_created || ActualWidth <= 0 || ActualHeight <= 0)
            return;

        WebKitHostBridge.Initialize();
        var parentHwnd = WindowNative.GetWindowHandle(_ownerWindow);
        var (x, y, w, h) = GetFrameInWindowPixels();
        _nativeView = WebKitHostBridge.ViewCreate(parentHwnd, x, y, w, h);
        _created = _nativeView != 0;
    }

    /// <summary>Force layout sync (call after tab activation).</summary>
    public void SyncNativeFrame() => UpdateNativeFrame();

    private void UpdateNativeFrame()
    {
        if (!_created && ActualWidth > 0 && ActualHeight > 0)
        {
            EnsureNativeView();
            return;
        }
        if (_nativeView == 0) return;
        var (x, y, w, h) = GetFrameInWindowPixels();
        WebKitHostBridge.ViewSetFrame(_nativeView, x, y, w, h);
    }

    private (int x, int y, int w, int h) GetFrameInWindowPixels()
    {
        var scale = XamlRoot?.RasterizationScale ?? 1.0;
        var transform = TransformToVisual(null);
        var point = transform.TransformPoint(new Point(0, 0));
        return (
            (int)(point.X * scale),
            (int)(point.Y * scale),
            Math.Max(1, (int)(ActualWidth * scale)),
            Math.Max(1, (int)(ActualHeight * scale)));
    }

    private void DestroyNativeView()
    {
        if (_nativeView == 0) return;
        WebKitHostBridge.ViewDestroy(_nativeView);
        _nativeView = 0;
        _created = false;
    }
}
