using System.Linq;
using System.Threading;
using FlaUI.Core.AutomationElements;
using Xunit;

namespace Webkitium.Harness;

[Trait("Smoke", "true")]
[Trait("Feature", "multiple_tabs")]
public class MultipleTabsTests
{
    [Fact]
    public void New_tab_then_close_tab_round_trips_count()
    {
        using var fx = new HarnessFixture();

        var tabsBefore = CountTabs(fx);
        fx.FindByName("New tab").AsButton().Invoke();
        Thread.Sleep(800);

        var tabsAfter = CountTabs(fx);
        Assert.True(tabsAfter >= tabsBefore + 1, $"expected ≥{tabsBefore + 1} tabs, got {tabsAfter}");

        // Close one — the per-tab close button is named "Close tab"; the
        // TabView puts one of those on every TabViewItem.
        var closeButtons = fx.MainWindow.FindAllDescendants(cf => cf.ByName("Close tab"));
        Assert.True(closeButtons.Length >= 1);
        closeButtons[0].AsButton().Invoke();
        Thread.Sleep(800);

        Assert.True(CountTabs(fx) >= tabsBefore, "tab count should not drop below initial");
    }

    private static int CountTabs(HarnessFixture fx) =>
        fx.MainWindow.FindAllDescendants(cf => cf.ByControlType(FlaUI.Core.Definitions.ControlType.TabItem)).Length;
}
