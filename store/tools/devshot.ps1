# devshot.ps1 -Device fenix7 -BuildOnly [-Aod]   : builds the sample-data face for a device
# devshot.ps1 -Device fenix7 -Out dev\fenix7.png  : captures the round display from the simulator
# (launch the prg in between from a foreground console; see devloop.sh)
param([string]$Device, [string]$Out, [switch]$Aod, [switch]$BuildOnly)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$sdk = "$env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"

if ($BuildOnly) {
    $aodFlag = if ($Aod) { 'true' } else { 'false' }
    @"
import Toybox.Lang;
module ShotConfig {
    const AOD = $aodFlag;
    const ACCENT = 0xC8FF2E;
    const NUMERALS = 0xF4F4EF;
    const FIELDS = [0, 1, 10] as Array<Number>;
    const ARC = 0;
    const HOUR = 10;
    const MIN = 8;
    const SEC = 34;
}
"@ | Set-Content -Encoding ascii source\ShotConfig.mc
    & "$sdk\bin\monkeyc.bat" -f monkey.jungle -d $Device -o "bin\dev_$Device.prg" -y C:\Users\dariu\developer_key | Select-Object -Last 1
    exit 0
}

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Win2 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
}
'@
[Win2]::SetProcessDPIAware() | Out-Null

$sim = Get-Content "$env:APPDATA\Garmin\ConnectIQ\Devices\$Device\simulator.json" -Raw | ConvertFrom-Json
$loc = $sim.display.location
$devImg = [System.Drawing.Image]::FromFile("$env:APPDATA\Garmin\ConnectIQ\Devices\$Device\$($sim.image)")
$devH = $devImg.Height
$devImg.Dispose()

$p = Get-Process simulator | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
[Win2]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
Start-Sleep -Milliseconds 800
$r = New-Object Win2+RECT
[Win2]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc(); [Win2]::PrintWindow($p.MainWindowHandle, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $g.Dispose()

# Window chrome: 8 px side border; the menu bar can wrap, so measure from the bottom
# (8 px border + 21 px status bar under the device image)
$ox = 8 + $loc.x; $oy = ($r.B - $r.T) - 8 - 21 - $devH + $loc.y; $w = $loc.width; $h = $loc.height
$face = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($face)
$g.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), (New-Object System.Drawing.Rectangle $ox, $oy, $w, $h), 'Pixel')
$g.Dispose()
$face.Save((Join-Path $PSScriptRoot $Out), [System.Drawing.Imaging.ImageFormat]::Png)
"$Device ${w}x$h saved ($($p.MainWindowTitle))"
$face.Dispose(); $bmp.Dispose()
