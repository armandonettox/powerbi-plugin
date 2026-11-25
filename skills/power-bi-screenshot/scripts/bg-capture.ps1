# Background capture of the Power BI Desktop window (no focus change, no cursor use) and optional hover by window message.
# Usage: bg-capture.ps1 -Output shot.png [-HoverX 570 -HoverY 583 -WaitMs 1500] [-Info]
param(
    [string]$Output = (Join-Path $env:TEMP "claude\powerbi-bg.png"),
    [int]$HoverX = -1,
    [int]$HoverY = -1,
    [int]$WaitMs = 1500,
    [switch]$Info
)

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class BgApi {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public static List<IntPtr> Widgets(IntPtr parent) {
        var l = new List<IntPtr>();
        EnumChildWindows(parent, (h, x) => { var sb = new StringBuilder(256); GetClassName(h, sb, 256);
            if (sb.ToString() == "Chrome_RenderWidgetHostHWND") l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
}
"@
[BgApi]::SetProcessDPIAware() | Out-Null

$proc = Get-Process -Name PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Error "PBIDesktop has no visible window."; exit 1 }
$hwnd = $proc.MainWindowHandle

function Save-Window($h, $path) {
    $r = New-Object BgApi+RECT; [BgApi]::GetWindowRect($h, [ref]$r) | Out-Null
    $w = $r.Right - $r.Left; $hh = $r.Bottom - $r.Top
    $bmp = New-Object System.Drawing.Bitmap $w, $hh
    $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
    [BgApi]::PrintWindow($h, $hdc, 2) | Out-Null   # 2 = PW_RENDERFULLCONTENT
    $g.ReleaseHdc($hdc); $g.Dispose()
    $dir = Split-Path $path -Parent; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

if ($Info) {
    $m = New-Object BgApi+RECT; [BgApi]::GetWindowRect($hwnd, [ref]$m) | Out-Null
    "main: $($m.Left),$($m.Top) $($m.Right-$m.Left)x$($m.Bottom-$m.Top)"
    foreach ($w in [BgApi]::Widgets($hwnd)) {
        $r = New-Object BgApi+RECT; [BgApi]::GetWindowRect($w, [ref]$r) | Out-Null
        "widget $($w.ToInt64()): $($r.Left),$($r.Top) $($r.Right-$r.Left)x$($r.Bottom-$r.Top)"
    }
}

if ($HoverX -ge 0) {
    # coordinates are in the captured image; convert to the client space of each widget and post mouse moves
    $m = New-Object BgApi+RECT; [BgApi]::GetWindowRect($hwnd, [ref]$m) | Out-Null
    foreach ($w in [BgApi]::Widgets($hwnd)) {
        $r = New-Object BgApi+RECT; [BgApi]::GetWindowRect($w, [ref]$r) | Out-Null
        $cx = $HoverX + $m.Left - $r.Left; $cy = $HoverY + $m.Top - $r.Top
        foreach ($d in @(-30, -10, 0, 1)) {
            $lp = [IntPtr](((($cy + $d) -band 0xFFFF) -shl 16) -bor (($cx + $d) -band 0xFFFF))
            [BgApi]::PostMessage($w, 0x0200, [IntPtr]::Zero, $lp) | Out-Null   # WM_MOUSEMOVE
            Start-Sleep -Milliseconds 120
        }
    }
    Start-Sleep -Milliseconds $WaitMs
}

Save-Window $hwnd $Output
Write-Output $Output
