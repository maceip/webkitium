using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace WebkitiumChrome;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Title = "Webkitium";
        AddTab("Start", "https://example.com");
    }

    private void NewTab_Click(object sender, RoutedEventArgs e)
    {
        AddTab("New Tab", "https://example.com");
    }

    private void Tabs_AddTabButtonClick(TabView sender, object args)
    {
        AddTab("New Tab", "https://example.com");
    }

    private void AddTab(string title, string url)
    {
        var tab = new TabViewItem
        {
            Header = title,
            Content = new TextBlock
            {
                Text = url,
                Margin = new Thickness(24),
            },
        };

        Tabs.TabItems.Add(tab);
        Tabs.SelectedItem = tab;
    }
}
