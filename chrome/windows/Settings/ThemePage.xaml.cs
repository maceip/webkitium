using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace Webkitium.Settings;

public sealed partial class ThemePage : Page
{
    private bool _suppressPickerEvent;

    public ThemePage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        var seed = App.Current.Palette.CurrentSeedArgb;
        PushSeedToUi(seed);
    }

    private void OnPickerColorChanged(ColorPicker sender, ColorChangedEventArgs args)
    {
        if (_suppressPickerEvent) return;
        var c = args.NewColor;
        var argb = (uint)((0xFF << 24) | (c.R << 16) | (c.G << 8) | c.B);
        App.Current.Palette.ApplySeed(argb);
        PushSeedToUi(argb);
    }

    private void OnPresetClicked(object sender, RoutedEventArgs e)
    {
        if (sender is Button b && b.Tag is string raw && uint.TryParse(raw, out var argb))
        {
            App.Current.Palette.ApplySeed(argb);
            PushSeedToUi(argb);
        }
    }

    private void PushSeedToUi(uint argb)
    {
        CurrentSeedCard.Description = $"#{argb & 0x00FFFFFF:X6}";

        var color = Windows.UI.Color.FromArgb(
            0xFF,
            (byte)((argb >> 16) & 0xFF),
            (byte)((argb >> 8) & 0xFF),
            (byte)(argb & 0xFF));
        CurrentSwatch.Background = new SolidColorBrush(color);

        _suppressPickerEvent = true;
        SeedPicker.Color = color;
        _suppressPickerEvent = false;
    }
}
