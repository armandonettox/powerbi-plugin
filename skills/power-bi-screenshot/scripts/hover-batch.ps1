# Hover over several points of the Power BI Desktop window, capturing each tooltip in the background.
# Targets are points in the window image (same pixels as a PrintWindow capture): "name:x:y;name:x:y"
# The user's cursor is saved first and restored at the end. The window focus is not changed.
param(
    [Parameter(Mandatory = $true)][string]$Targets,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [int]$WaitMs = 1600,
    [int]$CropW = 760,
    [int]$CropH = 520
)

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HbApi {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] i, int size);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    // Alt tap lets SetForegroundWindow work from a background process
    public static void Activate(IntPtr h) {
        keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);
        SetForegroundWindow(h);
    }
    public static void Wheel(int notches) {
        var inp = new INPUT[1];
        inp[0].type = 0; inp[0].mi.dwFlags = 0x0800;  // WHEEL
        inp[0].mi.mouseData = unchecked((uint)(notches * 120));
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void Click() {
        var inp = new INPUT[2];
        inp[0].type = 0; inp[0].mi.dwFlags = 0x0002;  // LEFTDOWN
        inp[1].type = 0; inp[1].mi.dwFlags = 0x0004;  // LEFTUP
        SendInput(2, inp, Marshal.SizeOf(typeof(INPUT)));
    }
    public struct RECT { public int Left, Top, Right, Bottom; }
    public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT { public uint type; public MOUSEINPUT mi; }
    public static void MoveTo(int x, int y) {
        int vx = GetSystemMetrics(76), vy = GetSystemMetrics(77), vw = GetSystemMetrics(78), vh = GetSystemMetrics(79);
        var inp = new INPUT[1];
        inp[0].type = 0;
        inp[0].mi.dx = (int)(((x - vx) * 65535.0) / (vw - 1));
        inp[0].mi.dy = (int)(((y - vy) * 65535.0) / (vh - 1));
        inp[0].mi.dwFlags = 0x0001 | 0x8000 | 0x4000;  // MOVE | ABSOLUTE | VIRTUALDESK
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }
}
"@
[HbApi]::SetProcessDPIAware() | Out-Null

$proc = Get-Process -Name PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Error "PBIDesktop has no visible window."; exit 1 }
$hwnd = $proc.MainWindowHandle
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }

$saved = New-Object HbApi+POINT
[HbApi]::GetCursorPos([ref]$saved) | Out-Null
$prevWindow = [HbApi]::GetForegroundWindow()
if ([HbApi]::IsIconic($hwnd)) { [HbApi]::ShowWindow($hwnd, 9) | Out-Null }
[HbApi]::Activate($hwnd)
Start-Sleep -Milliseconds 700
$m = New-Object HbApi+RECT
[HbApi]::GetWindowRect($hwnd, [ref]$m) | Out-Null
$w = $m.Right - $m.Left; $h = $m.Bottom - $m.Top

try {
    if ($Targets -eq "snapshot") {
        # full window image after activation, no cursor movement: use it to pick hover coordinates
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($m.Left, $m.Top, 0, 0, $bmp.Size); $g.Dispose()
        $file = Join-Path $OutDir "snapshot.png"; $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
        Write-Output $file
        return
    }
    foreach ($t in ($Targets -split ';')) {
        $p = $t -split ':'
        $name = $p[0]; $x = [int]$p[1]; $y = [int]$p[2]
        $sx = $m.Left + $x; $sy = $m.Top + $y
        # repeats the approach until the cursor really arrives (the first move after a focus change can be lost)
        for ($try = 0; $try -lt 4; $try++) {
            [HbApi]::MoveTo($sx - 40, $sy - 25); Start-Sleep -Milliseconds 120
            [HbApi]::MoveTo($sx - 12, $sy - 8);  Start-Sleep -Milliseconds 120
            [HbApi]::MoveTo($sx, $sy);           Start-Sleep -Milliseconds 120
            [HbApi]::MoveTo($sx + 1, $sy + 1);   Start-Sleep -Milliseconds 150
            $chk = New-Object HbApi+POINT; [HbApi]::GetCursorPos([ref]$chk) | Out-Null
            if ([Math]::Abs($chk.X - ($sx + 1)) -le 3 -and [Math]::Abs($chk.Y - ($sy + 1)) -le 3) { break }
        }
        if ($name -like "scroll-*") {
            # target format: scroll-name:x:y:notches (negative notches scroll down)
            [HbApi]::Wheel([int]$p[3]); Start-Sleep -Milliseconds 1500
        } elseif ($name -like "*click-*") {
            # navigation: click (Ctrl+click for report buttons in Desktop), move the cursor away so no tooltip stays open, and wait for the page to draw
            if ($name -like "ctrlclick-*") { [HbApi]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero) }
            [HbApi]::Click()
            if ($name -like "ctrlclick-*") { [HbApi]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero) }
            Start-Sleep -Milliseconds 300
            [HbApi]::MoveTo($m.Left + 10, $m.Top + 400)
            if ($name -like "click-fast*") { Start-Sleep -Milliseconds $WaitMs } else { Start-Sleep -Milliseconds ([Math]::Max($WaitMs, 3500)) }
        } else {
            Start-Sleep -Milliseconds $WaitMs
        }
        $now = New-Object HbApi+POINT; [HbApi]::GetCursorPos([ref]$now) | Out-Null
        Write-Output "cursor at $($now.X),$($now.Y) (target $sx,$sy)"
        # screen capture (not PrintWindow) so floating tooltip windows are included
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($m.Left, $m.Top, 0, 0, $bmp.Size)
        $g.Dispose()

        # saves the whole window: the tooltip opens beside the cursor and a fixed crop cut it in half
        $file = Join-Path $OutDir "$name.png"
        $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        Write-Output $file
    }
}
finally {
    [HbApi]::SetCursorPos($saved.X, $saved.Y) | Out-Null   # gives the cursor back
    if ($prevWindow -ne [IntPtr]::Zero -and $prevWindow -ne $hwnd) { [HbApi]::Activate($prevWindow) }   # gives the focus back
}
