using System;
using System.Drawing;
using System.Runtime.InteropServices;

public class WinCapture {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string t);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }

    public static bool Capture(string title, string path) {
        var h = FindWindow(null, title);
        if (h == IntPtr.Zero) return false;
        RECT r; GetWindowRect(h, out r);
        int w = r.R - r.L, ht = r.B - r.T;
        if (w <= 0 || ht <= 0) { w = 1280; ht = 800; }
        using (var b = new Bitmap(w, ht)) {
            using (var g = Graphics.FromImage(b)) {
                var dc = g.GetHdc();
                PrintWindow(h, dc, 0x2);
                g.ReleaseHdc(dc);
            }
            b.Save(path);
            return true;
        }
    }
}
