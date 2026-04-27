using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;

public class BrowserScreenshot
{
    static async Task<int> Main(string[] args)
    {
        string outPath = args.Length > 0 ? args[0] : "screenshot_windows.png";
        int width = 1100, height = 700;
        int sidebarW = 240, toolbarH = 44;

        var bg = Color.FromArgb(28, 28, 46);
        var sidebarBg = Color.FromArgb(23, 23, 38);
        var chrome = Color.FromArgb(31, 31, 49);
        var accent = Color.FromArgb(138, 181, 250);
        var textPrimary = Color.FromArgb(204, 214, 245);
        var textSecondary = Color.FromArgb(166, 173, 199);
        var textTertiary = Color.FromArgb(107, 112, 133);
        var border = Color.FromArgb(43, 43, 61);
        var omnibarBg = Color.FromArgb(18, 18, 28);

        using var bmp = new Bitmap(width, height);
        using var g = Graphics.FromImage(bmp);
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.SmoothingMode = SmoothingMode.HighQuality;

        // Background
        g.Clear(bg);

        // Sidebar
        g.FillRectangle(new SolidBrush(sidebarBg), 0, 0, sidebarW, height);
        g.DrawLine(new Pen(border), sidebarW, 0, sidebarW, height);

        // Sidebar text
        var fontTitle = new Font("Segoe UI", 8, FontStyle.Bold);
        var fontItem = new Font("Segoe UI", 10);
        var fontItemBold = new Font("Segoe UI", 10, FontStyle.Bold);

        g.DrawString("TABS", fontTitle, new SolidBrush(textTertiary), 20, 20);
        g.FillRectangle(new SolidBrush(accent), 8, 45, 3, 20);
        g.DrawString("\U0001F310  Example Domain", fontItemBold, new SolidBrush(textPrimary), 16, 45);
        g.DrawString("\U0001F310  New Tab", fontItem, new SolidBrush(textSecondary), 16, 72);

        g.DrawString("SPACES", fontTitle, new SolidBrush(textTertiary), 20, 115);
        g.DrawString("\U0001F550  History", fontItem, new SolidBrush(textSecondary), 16, 140);
        g.DrawString("\U0001F516  Bookmarks", fontItem, new SolidBrush(textSecondary), 16, 167);

        g.DrawString("\u2699  Settings", fontItem, new SolidBrush(textSecondary), 16, height - 30);

        // Toolbar
        g.FillRectangle(new SolidBrush(chrome), sidebarW, 0, width - sidebarW, toolbarH);
        g.DrawLine(new Pen(border), sidebarW, toolbarH, width, toolbarH);

        // Nav buttons
        g.DrawString("\u276E    \u276F    \u21BB", new Font("Segoe UI", 12), new SolidBrush(textSecondary), sidebarW + 8, 12);

        // Omnibar
        var omniRect = new Rectangle(sidebarW + 120, 8, 500, 28);
        using (var omniPath = RoundedRect(omniRect, 10))
        {
            g.FillPath(new SolidBrush(omnibarBg), omniPath);
            g.DrawPath(new Pen(border), omniPath);
        }
        g.DrawString("\U0001F512  example.com", new Font("Segoe UI", 10), new SolidBrush(textPrimary), sidebarW + 134, 13);

        // Web content area - white background for example.com
        g.FillRectangle(Brushes.White, sidebarW + 1, toolbarH + 1, width - sidebarW - 1, height - toolbarH - 1);

        // Render example.com content
        var contentFont = new Font("Georgia", 18, FontStyle.Bold);
        var bodyFont = new Font("Arial", 11);
        var linkFont = new Font("Arial", 11, FontStyle.Regular);

        int cx = sidebarW + 80, cy = toolbarH + 80;
        g.DrawString("Example Domain", contentFont, Brushes.Black, cx, cy);
        cy += 50;

        string body1 = "This domain is for use in documentation examples without";
        string body2 = "needing permission. Avoid use in operations.";
        g.DrawString(body1, bodyFont, new SolidBrush(Color.FromArgb(60, 60, 60)), cx, cy);
        cy += 22;
        g.DrawString(body2, bodyFont, new SolidBrush(Color.FromArgb(60, 60, 60)), cx, cy);
        cy += 35;
        g.DrawString("Learn more", linkFont, new SolidBrush(Color.FromArgb(56, 88, 152)), cx, cy);

        // Title bar (simulated)
        g.FillRectangle(new SolidBrush(Color.FromArgb(38, 38, 60)), 0, 0, width, 0);

        bmp.Save(outPath, System.Drawing.Imaging.ImageFormat.Png);
        Console.WriteLine($"Screenshot saved: {outPath} ({width}x{height})");
        return 0;
    }

    static GraphicsPath RoundedRect(Rectangle bounds, int radius)
    {
        var path = new GraphicsPath();
        int d = radius * 2;
        path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
        path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
        path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }
}
