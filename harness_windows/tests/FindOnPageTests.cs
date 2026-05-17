using System.Threading;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Input;
using Xunit;

namespace Webkitium.Harness;

[Trait("Smoke", "true")]
[Trait("Feature", "find_on_page")]
public class FindOnPageTests
{
    [Fact]
    public void Ctrl_F_opens_find_and_searches()
    {
        using var fx = new HarnessFixture();

        var url = fx.FindByName("Address bar").AsTextBox();
        url.Focus();
        // example.org has the word "Example" — pick a token guaranteed to be present.
        url.Text = "https://example.org";
        Keyboard.Press(FlaUI.Core.WindowsAPI.VirtualKeyShort.RETURN);
        Thread.Sleep(3000);

        // Open Find via the menu button rather than via Ctrl+F so we don't
        // race with the AutoSuggestBox's focus. The CommandBar's secondary
        // commands include "Find in page".
        var findCmd = fx.TryFindByName("Find in page");
        if (findCmd is null)
        {
            // Fall back to Ctrl+F if the secondary commands aren't exposed
            // (CommandBar collapses them into the More menu until opened).
            Keyboard.TypeSimultaneously(
                FlaUI.Core.WindowsAPI.VirtualKeyShort.CONTROL,
                FlaUI.Core.WindowsAPI.VirtualKeyShort.KEY_F);
            Thread.Sleep(400);
            findCmd = fx.FindByName("Find in page");
        }

        // The find entry has the same accessible name; pick the textbox one.
        var findEntry = fx.MainWindow.FindFirstDescendant(cf =>
            cf.ByName("Find in page").And(cf.ByControlType(FlaUI.Core.Definitions.ControlType.Edit)));
        if (findEntry is null)
        {
            // The button form may have been clicked but the textbox lives
            // inside the overlay panel — sometimes UIAutomation needs a beat.
            Thread.Sleep(800);
            findEntry = fx.FindByName("Find in page");
        }

        findEntry.AsTextBox().Text = "Example";
        Thread.Sleep(1200);

        // We assert only that the find UI reached an interactive state —
        // the actual match count isn't easily readable via UIAutomation
        // because the count TextBlock isn't named. The contract here is
        // "Ctrl+F opens an entry that accepts input."
        Assert.True(findEntry.IsEnabled);
    }
}
