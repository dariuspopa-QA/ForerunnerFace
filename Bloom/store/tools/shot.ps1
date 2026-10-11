# shot.ps1 -Work <scratch copy> -Tag rose [-Palette 0] [-Highlight 0xFF8A3D] [-Hour 16 -Min 8] [-Aod] [-Device fr970]
#     builds the demo face (demo.jungle) with pinned colours into <work>\bin\shot_<device>_<tag>.prg
# shot.ps1 -Work <scratch copy> -Device fr970 -Out <png>
#     captures the round display from the running simulator
# (launch the prg in between: see README.md)
param([string]$Work, [string]$Tag, [int]$Palette = -1, [string]$Highlight = "-1", [int]$Hour = 16, [int]$Min = 8,
    [switch]$Aod, [string]$Device = "fr970", [string]$Out)
$ErrorActionPreference = 'Stop'
$sdk = "$env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"

if (-not $Out) {
    $demo = Join-Path $Work 'tools\demo\FaceDemo.mc'
    $src = Get-Content $demo -Raw
    $src = $src -replace 'const FORCE_AOD = \w+;', ("const FORCE_AOD = {0};" -f $(if ($Aod) { 'true' } else { 'false' }))
    $src = $src -replace 'const PALETTE = -?\w+;', "const PALETTE = $Palette;"
    $src = $src -replace 'const HIGHLIGHT = -?\w+;', "const HIGHLIGHT = $Highlight;"
    $src = $src -replace 'clock\.hour = \d+;', "clock.hour = $Hour;" -replace 'now\.hour = \d+;', "now.hour = $Hour;"
    $src = $src -replace 'clock\.min = \d+;', "clock.min = $Min;" -replace 'now\.min = \d+;', "now.min = $Min;"
    Set-Content -Encoding ascii $demo $src
    & "$sdk\bin\monkeyc.bat" -f (Join-Path $Work 'demo.jungle') -d $Device -o (Join-Path $Work "bin\shot_$Device`_$Tag.prg") -y C:\Users\dariu\developer_key | Select-Object -Last 1
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
$face.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"$Device ${w}x$h saved ($($p.MainWindowTitle))"
$face.Dispose(); $bmp.Dispose()
