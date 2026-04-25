// Compact-by-default omnibar with click-to-expand suggestions.
//
// Click on the pill (or focus its input) opens a Popup that mirrors the
// input field at full width with a suggestion list underneath. Light-
// dismiss closes it; ESC explicitly closes; Enter would submit (wired to
// MainWindow when the navigate-active-tab routing lands).

using System;
using System.Collections.Generic;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using Windows.System;

namespace Webkitium.Views;

public sealed partial class Omnibar : UserControl
{
    public sealed record Suggestion(string Symbol, string Title, string Subtitle);

    /// <summary>Raised when the user submits a URL or query.</summary>
    public event EventHandler<string>? Submitted;

    public Omnibar()
    {
        InitializeComponent();
        SeedDefaultSuggestions();
    }

    // -- Compact pill input ------------------------------------------------

    private void OnInputGotFocus(object sender, RoutedEventArgs e)
    {
        OpenExpanded(initialText: Input.Text);
    }

    private void OnInputLostFocus(object sender, RoutedEventArgs e)
    {
        // The Popup steals focus when it opens, which fires LostFocus on
        // the compact input -- ignore. Closing happens via Popup's
        // light-dismiss + OnPopupClosed.
    }

    private void OnInputKeyDown(object sender, Microsoft.UI.Xaml.Input.KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Enter)
        {
            Submit(Input.Text);
            e.Handled = true;
        }
    }

    // -- Expanded popup ---------------------------------------------------

    private void OpenExpanded(string initialText)
    {
        ExpandedInput.Text = initialText;
        // Top-left aligned with the pill's top-left so the popup
        // OVERLAYS the address bar entirely (per design rules screenshot).
        // Width >= pill width, expanding rightward and downward.
        ExpandedPopup.HorizontalOffset = 0;
        ExpandedPopup.VerticalOffset = 0;
        ExpandedRoot.Width = Math.Max(Pill.ActualWidth, 640);
        ExpandedPopup.IsOpen = true;
        ExpandedInput.SelectAll();
        ExpandedInput.Focus(FocusState.Programmatic);
    }

    private void OnPopupClosed(object? sender, object e)
    {
        // Sync any text typed in the popup back to the compact pill.
        Input.Text = ExpandedInput.Text;
    }

    private void OnExpandedKeyDown(object sender, Microsoft.UI.Xaml.Input.KeyRoutedEventArgs e)
    {
        switch (e.Key)
        {
            case VirtualKey.Enter:
                Submit(ExpandedInput.Text);
                e.Handled = true;
                break;
            case VirtualKey.Escape:
                ExpandedPopup.IsOpen = false;
                e.Handled = true;
                break;
        }
    }

    private void OnExpandedTextChanged(object sender, TextChangedEventArgs e)
    {
        // Stub: filter the suggestions by prefix. Replace with real
        // omnibox suggestion service when wired.
    }

    private void OnSuggestionClicked(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is Suggestion s)
        {
            // Strip "scheme:" if subtitle contains a URL with one.
            Submit(s.Subtitle);
        }
    }

    private void OnCollapseClicked(object sender, RoutedEventArgs e)
    {
        ExpandedPopup.IsOpen = false;
    }

    private void Submit(string text)
    {
        ExpandedPopup.IsOpen = false;
        if (!string.IsNullOrWhiteSpace(text))
        {
            Submitted?.Invoke(this, text);
        }
    }

    // -- Suggestion seeding ----------------------------------------------

    private void SeedDefaultSuggestions()
    {
        // Stub list mirroring the design rules screenshot. Replaced when
        // the real suggestion service is wired through browser/.
        var stubs = new List<Suggestion>
        {
            new("Globe",      "Hacker News",        "news.ycombinator.com"),
            new("Globe",      "Google News",        "news.google.com"),
            new("Document",   "New tab",            "chrome://newtab"),
            new("Bookmarks",  "New Balance",        "Footwear company"),
            new("Globe",      "Google News",        "news.google.com/home?hl=en-US"),
            new("Bookmarks",  "New Design Congress","newdesigncongress.org/en/"),
            new("Bookmarks",  "nw",                 "github.com/newrelic/node-newrelic/issues/295"),
            new("Bookmarks",  "con",                "github.com/newrelic/node-newrelic/issues/344"),
        };

        Suggestions.Items.Clear();
        foreach (var s in stubs)
        {
            Suggestions.Items.Add(BuildSuggestionRow(s));
        }
    }

    private FrameworkElement BuildSuggestionRow(Suggestion s)
    {
        var row = new Grid { ColumnSpacing = 10 };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var icon = new SymbolIcon
        {
            Symbol = ResolveSymbol(s.Symbol),
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(icon, 0);

        var stack = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var title = new TextBlock
        {
            Text = s.Title,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            Foreground = (Brush)Application.Current.Resources["TextPrimary"],
        };
        var sep = new TextBlock { Text = "—", Foreground = (Brush)Application.Current.Resources["TextTertiary"] };
        var subtitle = new TextBlock
        {
            Text = s.Subtitle,
            Foreground = (Brush)Application.Current.Resources["TextLink"],
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        stack.Children.Add(title);
        stack.Children.Add(sep);
        stack.Children.Add(subtitle);
        Grid.SetColumn(stack, 1);

        row.Children.Add(icon);
        row.Children.Add(stack);
        // Tag the row with the underlying suggestion for click handling.
        row.Tag = s;
        return row;
    }

    private static Symbol ResolveSymbol(string name)
    {
        return name switch
        {
            "Globe"     => Symbol.Globe,
            "Document"  => Symbol.Document,
            "Bookmarks" => Symbol.Bookmarks,
            _           => Symbol.World,
        };
    }
}
