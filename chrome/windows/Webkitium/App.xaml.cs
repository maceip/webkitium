using Microsoft.UI.Xaml;

namespace Webkitium;

public partial class App : Application
{
    // Holding the Window reference here is load-bearing: WinUI 3 doesn't
    // pin Windows for you, and letting it get collected closes the app.
    public Window? MainWindow { get; private set; }

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        MainWindow = new MainWindow();
        MainWindow.Activate();
    }
}
