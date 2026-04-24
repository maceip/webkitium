// Manual entry point for unpackaged WinUI 3.
//
// WinAppSDK's XAML compiler auto-generates a Main when UseWinUI=true,
// but for an unpackaged app we need to set the single-threaded apartment
// and hand-wire the dispatcher.  DISABLE_XAML_GENERATED_MAIN in the
// .csproj suppresses the auto-generated version so this one wins.

using System;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using WinRT;

namespace Webkitium;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        ComWrappersSupport.InitializeComWrappers();

        Application.Start((p) =>
        {
            var dq = DispatcherQueue.GetForCurrentThread();
            var ctx = new DispatcherQueueSynchronizationContext(dq);
            System.Threading.SynchronizationContext.SetSynchronizationContext(ctx);
            _ = new App();
        });

        return 0;
    }
}
