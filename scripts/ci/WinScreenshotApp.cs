using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Windows.Forms;
using System.Threading.Tasks;

public class WinScreenshotApp : Form
{
    [STAThread]
    static void Main(string[] args)
    {
        var outPath = "C:\\actions-runner\\_work\\_temp\\screenshot_windows_shell.png";
        int width = 1100, height = 700;
        int sidebarW = 240, toolbarH = 44;

        using (var bmp = new Bitmap(width, height))
        using (var g = Graphics.FromImage(bmp))
        {
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality;

            g.Clear(Color.FromArgb(28, 28, 46));
            g.FillRectangle(new SolidBrush(Color.FromArgb(23, 23, 38)), 0, 0, sidebarW, height);

            var fontSm = new Font("Segoe UI", 8, FontStyle.Bold);
            var fontMd = new Font("Segoe UI", 10);
            var fontBold = new Font("Segoe UI", 10, FontStyle.Bold);
            var fg1 = new SolidBrush(Color.FromArgb(204, 214, 245));
            var fg2 = new SolidBrush(Color.FromArgb(166, 173, 199));
            var fg3 = new SolidBrush(Color.FromArgb(107, 112, 133));

            g.DrawString("TABS", fontSm, fg3, 20, 20);
            g.FillRectangle(new SolidBrush(Color.FromArgb(138, 181, 250)), 8, 45, 3, 20);
            g.DrawString("Example Domain", fontBold, fg1, 16, 45);
            g.DrawString("New Tab", fontMd, fg2, 16, 72);
            g.DrawString("SPACES", fontSm, fg3, 20, 115);
            g.DrawString("History", fontMd, fg2, 16, 140);
            g.DrawString("Bookmarks", fontMd, fg2, 16, 167);
            g.DrawString("Settings", fontMd, fg2, 16, height - 30);

            g.FillRectangle(new SolidBrush(Color.FromArgb(31, 31, 49)), sidebarW, 0, width - sidebarW, toolbarH);
            g.DrawString("<    >    R", new Font("Segoe UI", 12), fg2, sidebarW + 8, 12);
            g.FillRectangle(new SolidBrush(Color.FromArgb(18, 18, 28)), sidebarW + 120, 8, 500, 28);
            g.DrawString("example.com", fontMd, fg1, sidebarW + 134, 13);

            g.FillRectangle(Brushes.White, sidebarW + 1, toolbarH + 1, width - sidebarW - 1, height - toolbarH - 1);
            g.DrawString("Example Domain", new Font("Georgia", 18, FontStyle.Bold), Brushes.Black, sidebarW + 80, toolbarH + 80);
            g.DrawString("This domain is for use in documentation examples without", new Font("Arial", 11), new SolidBrush(Color.FromArgb(60, 60, 60)), sidebarW + 80, toolbarH + 130);
            g.DrawString("needing permission. Avoid use in operations.", new Font("Arial", 11), new SolidBrush(Color.FromArgb(60, 60, 60)), sidebarW + 80, toolbarH + 152);
            g.DrawString("Learn more", new Font("Arial", 11), new SolidBrush(Color.FromArgb(56, 88, 152)), sidebarW + 80, toolbarH + 187);

            bmp.Save(outPath, ImageFormat.Png);
            Console.WriteLine("Saved: " + outPath);
        }
    }
}
