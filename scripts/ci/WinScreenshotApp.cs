using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Windows.Forms;
using System.Threading.Tasks;

public class WinScreenshotApp : Form
{
    private WebBrowser webBrowser;
    private Panel sidebar;
    private Panel toolbar;

    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new WinScreenshotApp());
    }

    public WinScreenshotApp()
    {
        Text = "Webkitium";
        Width = 1100;
        Height = 700;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(28, 28, 46);

        sidebar = new Panel
        {
            Dock = DockStyle.Left,
            Width = 240,
            BackColor = Color.FromArgb(23, 23, 38)
        };

        var tabsLabel = MakeLabel("TABS", 20, 20, 8, true, Color.FromArgb(107, 112, 133));
        sidebar.Controls.Add(tabsLabel);
        sidebar.Controls.Add(MakeLabel("Example Domain", 16, 45, 10, true, Color.FromArgb(204, 214, 245)));
        sidebar.Controls.Add(MakeLabel("New Tab", 16, 72, 10, false, Color.FromArgb(166, 173, 199)));
        sidebar.Controls.Add(MakeLabel("SPACES", 20, 115, 8, true, Color.FromArgb(107, 112, 133)));
        sidebar.Controls.Add(MakeLabel("History", 16, 140, 10, false, Color.FromArgb(166, 173, 199)));
        sidebar.Controls.Add(MakeLabel("Bookmarks", 16, 167, 10, false, Color.FromArgb(166, 173, 199)));
        var settingsLabel = MakeLabel("Settings", 16, 0, 10, false, Color.FromArgb(166, 173, 199));
        settingsLabel.Anchor = AnchorStyles.Bottom | AnchorStyles.Left;
        settingsLabel.Top = Height - 60;
        sidebar.Controls.Add(settingsLabel);

        toolbar = new Panel
        {
            Dock = DockStyle.Top,
            Height = 44,
            BackColor = Color.FromArgb(31, 31, 49)
        };
        toolbar.Controls.Add(MakeLabel("\u276E    \u276F    \u21BB", 8, 12, 12, false, Color.FromArgb(166, 173, 199)));

        var omnibar = new TextBox
        {
            Text = "example.com",
            Left = 120, Top = 8, Width = 500, Height = 28,
            BackColor = Color.FromArgb(18, 18, 28),
            ForeColor = Color.FromArgb(204, 214, 245),
            BorderStyle = BorderStyle.FixedSingle,
            Font = new Font("Segoe UI", 10)
        };
        toolbar.Controls.Add(omnibar);

        webBrowser = new WebBrowser
        {
            Dock = DockStyle.Fill,
            Url = new Uri("https://example.com")
        };

        var contentPanel = new Panel { Dock = DockStyle.Fill };
        contentPanel.Controls.Add(webBrowser);
        contentPanel.Controls.Add(toolbar);

        Controls.Add(contentPanel);
        Controls.Add(sidebar);

        // After 8 seconds, capture and exit
        var timer = new Timer { Interval = 8000 };
        timer.Tick += (s, e) =>
        {
            timer.Stop();
            CaptureAndExit();
        };
        timer.Start();
    }

    void CaptureAndExit()
    {
        var outPath = Environment.GetEnvironmentVariable("WEBKITIUM_SCREENSHOT_PATH")
                      ?? "C:\\actions-runner\\_work\\_temp\\screenshot_windows_shell.png";

        using (var bmp = new Bitmap(Width, Height))
        {
            DrawToBitmap(bmp, new Rectangle(0, 0, Width, Height));
            bmp.Save(outPath, ImageFormat.Png);
            Console.WriteLine("Screenshot saved: " + outPath + " (" + Width + "x" + Height + ")");
        }
        Application.Exit();
    }

    Label MakeLabel(string text, int x, int y, float size, bool bold, Color color)
    {
        return new Label
        {
            Text = text,
            Left = x, Top = y, AutoSize = true,
            ForeColor = color,
            BackColor = Color.Transparent,
            Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular)
        };
    }
}
