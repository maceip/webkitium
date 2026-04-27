$p = Get-Process -Name webkitium -ErrorAction SilentlyContinue
if ($p) {
    Write-Host "APP_ALIVE pid=$($p.Id) handle=$($p.MainWindowHandle) title='$($p.MainWindowTitle)'"
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    using System.Text;
    public class WinEnum {
        public delegate bool EnumProc(IntPtr h, IntPtr l);
        [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
        [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    }
"@
    [WinEnum]::EnumWindows({
        param($h, $l)
        if ([WinEnum]::IsWindowVisible($h)) {
            $sb = New-Object System.Text.StringBuilder 256
            [WinEnum]::GetWindowText($h, $sb, 256)
            $pid = [uint32]0
            [WinEnum]::GetWindowThreadProcessId($h, [ref]$pid)
            if ($sb.Length -gt 0) {
                Write-Host "  WIN: pid=$pid '$($sb.ToString())'"
            }
        }
        return $true
    }, [IntPtr]::Zero)
} else {
    Write-Host "APP_DEAD"
}
