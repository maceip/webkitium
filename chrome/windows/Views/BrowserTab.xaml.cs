// A single tab: omnibar + WebView2. Each TabViewItem in MainWindow hosts
// one of these as its Content. Navigate() drives the WebView2 and is
// eventually fed from the Omnibar's submit handler.

using System;
using Microsoft.UI.Xaml.Controls;

namespace Webkitium.Views;

public sealed partial class BrowserTab : UserControl
{
    public BrowserTab()
    {
        InitializeComponent();
    }

    /// <summary>
    /// Load <paramref name="url"/> in this tab's WebView2.
    /// </summary>
    public void Navigate(Uri url)
    {
        PART_WebView.Source = url;
    }

    /// <summary>
    /// Initial URL assigned at tab creation.
    /// </summary>
    public Uri? InitialSource
    {
        get => PART_WebView.Source;
        set { if (value is not null) PART_WebView.Source = value; }
    }
}
