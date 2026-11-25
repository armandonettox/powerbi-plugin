# Hover over a point on screen with real input events, wait for the tooltip, and save a screenshot.
# Usage: powershell -File hover-screenshot.ps1 -X 1190 -Y 1660 [-Output "C:\path\shot.png"] [-WaitMs 1800]

param(
    [Parameter(Mandatory = $true)][int]$X,
    [Parameter(Mandatory = $true)][int]$Y,
    [string]$Output = (Join-Path $env:TEMP "claude\powerbi-hover.png"),
    [string]$ProcessName = "PBIDesktop",
    [int]$WaitMs = 1800
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HoverApi {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT { public uint type; public MOUSEINPUT mi; }
    const uint MOVE = 0x0001, ABSOLUTE = 0x8000, VIRTUALDESK = 0x4000;
    public static void MoveTo(int x, int y) {
        int vx = GetSystemMetrics(76), vy = GetSystemMetrics(77), vw = GetSystemMetrics(78), vh = GetSystemMetrics(79);
        var inp = new INPUT[1];
        inp[0].type = 0;
        inp[0].mi.dx = (int)(((x - vx) * 65535.0) / (vw - 1));
        inp[0].mi.dy = (int)(((y - vy) * 65535.0) / (vh - 1));
        inp[0].mi.dwFlags = MOVE | ABSOLUTE | VIRTUALDESK;
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }
}
"@

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Error "Process '$ProcessName' was not found or has no visible window."; exit 1 }

$hwnd = $proc.MainWindowHandle
[HoverApi]::ShowWindow($hwnd, 9) | Out-Null
[HoverApi]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 400

# Approach from a few pixels away so the visual sees a real mouse move, then rest on the target
[HoverApi]::MoveTo($X - 40, $Y - 25); Start-Sleep -Milliseconds 150
[HoverApi]::MoveTo($X - 12, $Y - 8);  Start-Sleep -Milliseconds 150
[HoverApi]::MoveTo($X, $Y);           Start-Sleep -Milliseconds 150
[HoverApi]::MoveTo($X + 1, $Y + 1);   Start-Sleep -Milliseconds $WaitMs

$rect = New-Object HoverApi+RECT
[HoverApi]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$left = [Math]::Max($rect.Left, [System.Windows.Forms.SystemInformation]::VirtualScreen.Left)
$top = [Math]::Max($rect.Top, [System.Windows.Forms.SystemInformation]::VirtualScreen.Top)
$width = $rect.Right - $left
$height = $rect.Bottom - $top
$bitmap = New-Object System.Drawing.Bitmap $width, $height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($left, $top, 0, 0, $bitmap.Size)

$dir = Split-Path $Output -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$bitmap.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose(); $bitmap.Dispose()
Write-Output $Output
