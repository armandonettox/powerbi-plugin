# Takes a screenshot of the Power BI Desktop window and saves it as a PNG.
# Usage: powershell -File capture-screenshot.ps1 [-Output "C:\path\shot.png"] [-ProcessName "PBIDesktop"]
# The path of the saved file is printed on success. Windows only.

param(
    [string]$Output = (Join-Path $env:TEMP "claude\powerbi-screenshot.png"),
    [string]$ProcessName = "PBIDesktop"
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int index);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    // Biggest visible window of the process, ignoring tool windows such as tooltips:
    // Process.MainWindowHandle can point at a tooltip that is still on screen
    public static IntPtr Largest(uint pid) {
        IntPtr best = IntPtr.Zero; long bestArea = 0;
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p != pid || !IsWindowVisible(h)) return true;
            if ((GetWindowLong(h, -20) & 0x80) != 0) return true;  // WS_EX_TOOLWINDOW
            RECT r; GetWindowRect(h, out r);
            long area = (long)(r.Right - r.Left) * (r.Bottom - r.Top);
            if (area > bestArea) { bestArea = area; best = h; }
            return true;
        }, IntPtr.Zero);
        return best;
    }
}
"@

# Without this, a screen scaled above 100% crops the image in the wrong place
[WinApi]::SetProcessDPIAware() | Out-Null

# Finds the first process with that name that has a visible window
$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1

if (-not $proc) {
    Write-Error "Process '$ProcessName' was not found or has no visible window."
    exit 1
}

$hwnd = [WinApi]::Largest([uint32]$proc.Id)
if ($hwnd -eq [IntPtr]::Zero) { $hwnd = $proc.MainWindowHandle }

# Restores the window if it is minimized and brings it to the front
[WinApi]::ShowWindow($hwnd, 9) | Out-Null  # SW_RESTORE
[WinApi]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

$rect = New-Object WinApi+RECT
[WinApi]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

$bitmap = New-Object System.Drawing.Bitmap $width, $height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)

$outputDir = Split-Path $Output -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$bitmap.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()

Write-Output $Output
