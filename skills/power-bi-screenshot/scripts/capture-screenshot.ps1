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
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

# Finds the first process with that name that has a visible window
$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1

if (-not $proc) {
    Write-Error "Process '$ProcessName' was not found or has no visible window."
    exit 1
}

$hwnd = $proc.MainWindowHandle

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
