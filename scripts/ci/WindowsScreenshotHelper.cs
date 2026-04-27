// CI-only: captures the MainWindow content after launch
// Add this file to the project during CI builds

using System;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Graphics.Imaging;
using Windows.Storage;
using Windows.Storage.Streams;

namespace webkitium;

public static class ScreenshotHelper
{
    public static async Task CaptureAfterDelay(Window window, int delayMs = 8000)
    {
        var screenshotPath = Environment.GetEnvironmentVariable("WEBKITIUM_SCREENSHOT_PATH");
        if (string.IsNullOrEmpty(screenshotPath)) return;

        await Task.Delay(delayMs);

        try
        {
            var rtb = new RenderTargetBitmap();
            await rtb.RenderAsync(window.Content as Microsoft.UI.Xaml.UIElement);
            var pixels = await rtb.GetPixelsAsync();

            var file = await StorageFile.GetFileFromPathAsync(screenshotPath)
                       ?? await StorageFile.CreateStreamedFileAsync("screenshot.png", null, null);

            using var stream = await FileIO.OpenStreamForWriteAsync(screenshotPath);
            var encoder = await BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, stream.AsRandomAccessStream());
            encoder.SetPixelData(
                BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied,
                (uint)rtb.PixelWidth, (uint)rtb.PixelHeight,
                96, 96, pixels.ToArray());
            await encoder.FlushAsync();
            System.Diagnostics.Debug.WriteLine($"Screenshot saved: {screenshotPath}");
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Screenshot failed: {ex.Message}");
        }

        Application.Current.Exit();
    }
}
