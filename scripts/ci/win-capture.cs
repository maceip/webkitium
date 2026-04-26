// Standalone capture utility -- compiled with Add-Type in PowerShell.
// On .NET Core/5+, System.Drawing.Bitmap lives in System.Drawing.Common.
// Fallback: use GDI directly without System.Drawing.

using System;
using System.Runtime.InteropServices;

public class WinCapture {
    [DllImport("user32.dll")] static extern IntPtr FindWindow(string c, string t);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern IntPtr GetWindowDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr d, int dx, int dy, int w, int h, IntPtr s, int sx, int sy, uint rop);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);

    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }

    // BMP file header structures
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct BITMAPFILEHEADER { public ushort bfType; public uint bfSize; public ushort bfR1, bfR2; public uint bfOffBits; }
    [StructLayout(LayoutKind.Sequential)]
    struct BITMAPINFOHEADER { public uint biSize; public int biWidth, biHeight; public ushort biPlanes, biBitCount; public uint biCompression, biSizeImage; public int biXPPM, biYPPM; public uint biClrUsed, biClrImportant; }

    [DllImport("gdi32.dll")] static extern int GetDIBits(IntPtr dc, IntPtr bmp, uint start, uint lines, byte[] bits, ref BITMAPINFOHEADER bi, uint usage);

    public static bool Capture(string title, string path) {
        var hwnd = FindWindow(null, title);
        if (hwnd == IntPtr.Zero) return false;
        RECT r; GetWindowRect(hwnd, out r);
        int w = r.R - r.L, h = r.B - r.T;
        if (w <= 0 || h <= 0) return false;

        var wdc = GetWindowDC(hwnd);
        var mdc = CreateCompatibleDC(wdc);
        var bmp = CreateCompatibleBitmap(wdc, w, h);
        var old = SelectObject(mdc, bmp);
        PrintWindow(hwnd, mdc, 0x2);
        SelectObject(mdc, old);

        // Extract bits and write BMP
        var bi = new BITMAPINFOHEADER { biSize = 40, biWidth = w, biHeight = h, biPlanes = 1, biBitCount = 32 };
        int stride = w * 4;
        var bits = new byte[stride * h];
        GetDIBits(mdc, bmp, 0, (uint)h, bits, ref bi, 0);

        var fh = new BITMAPFILEHEADER { bfType = 0x4D42, bfOffBits = 54, bfSize = (uint)(54 + bits.Length) };
        using (var fs = System.IO.File.Create(path)) {
            Write(fs, fh); Write(fs, bi); fs.Write(bits, 0, bits.Length);
        }

        DeleteObject(bmp); DeleteDC(mdc); ReleaseDC(hwnd, wdc);
        return true;
    }

    static void Write<T>(System.IO.Stream s, T val) where T : struct {
        int sz = Marshal.SizeOf(val);
        var buf = new byte[sz];
        var ptr = Marshal.AllocHGlobal(sz);
        Marshal.StructureToPtr(val, ptr, false);
        Marshal.Copy(ptr, buf, 0, sz);
        Marshal.FreeHGlobal(ptr);
        s.Write(buf, 0, sz);
    }
}
