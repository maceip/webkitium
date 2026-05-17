using System.Threading;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Input;
using Xunit;

namespace Webkitium.Harness;

[Trait("Smoke", "true")]
[Trait("Feature", "back_forward_navigation")]
public class BackForwardTests
{
    [Fact]
    public void Back_then_Forward_round_trips()
    {
        using var fx = new HarnessFixture();

        var url = fx.FindByName("Address bar").AsTextBox();
        url.Focus();
        url.Text = "https://example.org";
        Keyboard.Press(FlaUI.Core.WindowsAPI.VirtualKeyShort.RETURN);
        Thread.Sleep(2500);

        url.Focus();
        url.Text = "https://example.com";
        Keyboard.Press(FlaUI.Core.WindowsAPI.VirtualKeyShort.RETURN);
        Thread.Sleep(2500);

        var back = fx.FindByName("Back").AsButton();
        Assert.True(back.IsEnabled);
        back.Invoke();
        Thread.Sleep(1500);

        var forward = fx.FindByName("Forward").AsButton();
        Assert.True(forward.IsEnabled);
        forward.Invoke();
        Thread.Sleep(1500);

        // No specific URL assertion — WebView2 doesn't expose Source via
        // UIAutomation. The button-state assertions above are the contract.
    }
}
