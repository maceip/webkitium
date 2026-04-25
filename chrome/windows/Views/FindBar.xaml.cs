using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.System;

namespace Webkitium.Views;

public sealed partial class FindBar : UserControl
{
    public event EventHandler<string>? QuerySubmitted;
    public new event EventHandler? Closed;

    public FindBar()
    {
        InitializeComponent();
        Loaded += (_, _) => FindInput.Focus(FocusState.Programmatic);
    }

    private void OnFindKeyDown(object sender, Microsoft.UI.Xaml.Input.KeyRoutedEventArgs e)
    {
        if (e.Key == VirtualKey.Enter)
        {
            QuerySubmitted?.Invoke(this, FindInput.Text);
            e.Handled = true;
        }
        else if (e.Key == VirtualKey.Escape)
        {
            Closed?.Invoke(this, EventArgs.Empty);
            e.Handled = true;
        }
    }

    private void OnPrevious(object sender, RoutedEventArgs e)
        => QuerySubmitted?.Invoke(this, FindInput.Text);

    private void OnNext(object sender, RoutedEventArgs e)
        => QuerySubmitted?.Invoke(this, FindInput.Text);

    private void OnClose(object sender, RoutedEventArgs e)
        => Closed?.Invoke(this, EventArgs.Empty);
}
