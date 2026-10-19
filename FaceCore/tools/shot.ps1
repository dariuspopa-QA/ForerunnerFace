# Renders a face in the Connect IQ simulator and saves the round display as a PNG: the
# demo build (demo.jungle: fixed time and readings, tools/demo/FaceDemo.mc) of a scratch copy
# of the face, with the phone settings' defaults replaced for this shot. The drawing code
# is the face's own. (Adapted from Bloom/store/tools/shot.ps1.)
#
#   powershell -ExecutionPolicy Bypass -File FaceCore\tools\shot.ps1 -Face Meridian -Device fr970 -Out x.png
#       [-Props "AccentColor=0x3DDC97;RingMode=1"]   property defaults for this shot
#       [-Demo "PALETTE=2;FORCE_24H=false"]          constants in the demo FaceDemo module
#       [-Data "bodyBattery=80;steps=3100"]          readings set in the demo FaceDemo.apply
#       [-Hour 16 -Min 8 -Sec 42] [-Aod] [-Live] [-Wait 14]
#
# -Live builds monkey.jungle (real clock, simulator sensors) instead of the demo build.
# Needs the simulator running and visible (a minimised window can't be captured). Every
# shot starts from the face's defaults: the simulator's stored settings and storage for
# the shot build are deleted first.
param([Parameter(Mandatory)][string]$Face, [Parameter(Mandatory)][string]$Device, [Parameter(Mandatory)][string]$Out,
    [string]$Props = '', [string]$Demo = '', [string]$Data = '', [int]$Hour = -1, [int]$Min = -1, [int]$Sec = -1,
    [switch]$Aod, [switch]$Live, [int]$Wait = 14)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'products.ps1')
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$name = Split-Path -Leaf (Resolve-Path (Join-Path $repo $Face))

# ---- Scratch copy: <scratch>\FaceCore and <scratch>\<face> ----------------------------
$scratch = Join-Path $env:TEMP 'facecore-shot'
$work = Join-Path $scratch $name
foreach ($pair in @(@((Join-Path $repo 'FaceCore'), (Join-Path $scratch 'FaceCore')), @((Join-Path $repo $name), $work))) {
    robocopy $pair[0] $pair[1] /MIR /XD bin store dist design .git /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $($pair[0])" }
}

function Utf8NoBom([string]$path, [string]$text) {
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))   # a BOM breaks monkeyc
}

if ($Props) {
    $pf = Join-Path $work 'resources\settings\properties.xml'
    $xml = [IO.File]::ReadAllText($pf)
    foreach ($kv in $Props.Split(';') | Where-Object { $_ }) {
        $k, $v = $kv.Split('=', 2)
        $re = '(<property id="' + [regex]::Escape($k.Trim()) + '"[^>]*>)[^<]*(</property>)'
        if ($xml -notmatch $re) { throw "no property $k" }
        $xml = [regex]::Replace($xml, $re, ('${1}' + $v.Trim() + '${2}'))
    }
    Utf8NoBom $pf $xml
}

$jungle = if ($Live) { 'monkey.jungle' } else { 'demo.jungle' }
if (-not (Test-Path (Join-Path $work $jungle))) { $jungle = 'monkey.jungle' }
$demoFile = if ($jungle -eq 'demo.jungle') { Join-Path $work 'tools\demo\FaceDemo.mc' } else { Join-Path $work 'source-live\FaceDemo.mc' }

# A face without a demo build (GoalBars, PulseRings, TrainingPulse, MinimalFace) gets
# ShotData.mc.txt in its scratch copy, with its clock, date and sensor calls pointed at it
# (fixed time and readings, as the demo builds have). -Aod there: the sleeping screen.
if (-not $Live -and $jungle -eq 'monkey.jungle') {
    $shim = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ShotData.mc.txt'))
    if ($Hour -ge 0) { $shim = $shim -replace 'var hour as Number = \d+;', "var hour as Number = $Hour;" }
    if ($Min -ge 0) { $shim = $shim -replace 'var minute as Number = \d+;', "var minute as Number = $Min;" }
    if ($Sec -ge 0) { $shim = $shim -replace 'var second as Number = \d+;', "var second as Number = $Sec;" }
    Utf8NoBom (Join-Path $work 'source\ShotData.mc') $shim
    $files = @(Get-ChildItem (Join-Path $work 'source'), (Join-Path $scratch 'FaceCore\kit'), (Join-Path $scratch 'FaceCore\slots') -Filter '*.mc')
    foreach ($file in $files | Where-Object { $_.Name -notmatch 'Test\.mc$|^ShotData' }) {
        $text = [IO.File]::ReadAllText($file.FullName)
        $text = $text.Replace('System.getClockTime()', 'ShotData.clock()').Replace('ActivityMonitor.getInfo()', 'ShotData.info()')
        $text = $text.Replace('Activity.getActivityInfo()', 'ShotData.activity()').Replace('System.getSystemStats()', 'ShotData.stats()')
        $text = $text.Replace('Gregorian.info(Time.now(),', 'ShotData.greg(Time.now(),')
        if ($Aod) { $text = $text -replace '!_awake && burnIn', 'burnIn' }
        Utf8NoBom $file.FullName $text
    }
}

$src = [IO.File]::ReadAllText($demoFile)
$sets = @()
if ($src -match 'const FORCE_AOD') { if ($Aod) { $sets += 'FORCE_AOD=true' } else { $sets += 'FORCE_AOD=false' } }
if ($Demo) { $sets += $Demo.Split(';') | Where-Object { $_ } }
foreach ($kv in $sets) {
    $k, $v = $kv.Split('=', 2)
    $re = '(const ' + [regex]::Escape($k.Trim()) + ' = )[^;]+;'
    if ($src -notmatch $re) { throw "no constant $k in $demoFile" }
    $src = [regex]::Replace($src, $re, ('${1}' + $v.Trim() + ';'))
}
foreach ($kv in $Data.Split(';') | Where-Object { $_ }) {
    $k, $v = $kv.Split('=', 2)
    $re = '(data\.' + [regex]::Escape($k.Trim()) + ' = )[^;]+;'
    if ($src -notmatch $re) { throw "no data.$k in $demoFile" }
    $src = [regex]::Replace($src, $re, ('${1}' + $v.Trim() + ';'))
}
if ($Hour -ge 0) { $src = $src -replace 'clock\.hour = \d+;', "clock.hour = $Hour;" -replace 'now\.hour = \d+;', "now.hour = $Hour;" }
if ($Min -ge 0) { $src = $src -replace 'clock\.min = \d+;', "clock.min = $Min;" -replace 'now\.min = \d+;', "now.min = $Min;" }
if ($Sec -ge 0) { $src = $src -replace 'clock\.sec = \d+;', "clock.sec = $Sec;" }
Utf8NoBom $demoFile $src

# ---- Build ------------------------------------------------------------------------------
$prg = Join-Path $work 'bin\SHOT.prg'
New-Item -ItemType Directory -Force (Split-Path $prg) | Out-Null
$build = & "$Sdk\bin\monkeyc.bat" -f (Join-Path $work $jungle) -d $Device -o $prg -y $DevKey 2>&1
if (-not ($build -match 'BUILD SUCCESSFUL')) { $build | Select-Object -Last 15 | Out-Host; throw "build failed: $name $Device" }

# ---- Run in the simulator from clean settings --------------------------------------------
$apps = Join-Path $env:TEMP 'com.garmin.connectiq\GARMIN\APPS'
Get-ChildItem (Join-Path $apps 'SETTINGS'), (Join-Path $apps 'DATA') -Filter 'SHOT*' -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse
# The simulator's output per face and device: <scratch>\logs\<face>-<device>.log
$logs = Join-Path $scratch 'logs'
New-Item -ItemType Directory -Force $logs | Out-Null
$log = Join-Path $logs "$name-$Device.log"
# Both streams to files: an inherited handle would keep a caller's pipe open as long as
# monkeydo runs (it stays connected to the simulator until the next app replaces it)
$runner = Start-Process (Join-Path $Sdk 'bin\monkeydo.bat') -ArgumentList $prg, $Device -NoNewWindow -PassThru `
    -RedirectStandardOutput $log -RedirectStandardError (Join-Path $logs "$name-$Device.err.log")
Start-Sleep -Seconds $Wait

# ---- Capture the round display ----------------------------------------------------------
Add-Type -AssemblyName System.Drawing
if (-not ('Win2' -as [type])) {
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
}
[Win2]::SetProcessDPIAware() | Out-Null
$sim = Get-Content (Join-Path $DeviceDir "$Device\simulator.json") -Raw | ConvertFrom-Json
$loc = $sim.display.location
$devImg = [System.Drawing.Image]::FromFile((Join-Path $DeviceDir "$Device\$($sim.image)"))
$devH = $devImg.Height
$devImg.Dispose()
$p = Get-Process simulator | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { throw 'simulator window not found' }
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
$shot = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($shot)
$g.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), (New-Object System.Drawing.Rectangle $ox, $oy, $w, $h), 'Pixel')
$g.Dispose()
New-Item -ItemType Directory -Force (Split-Path -Parent ([IO.Path]::GetFullPath($Out))) | Out-Null
$shot.Save([IO.Path]::GetFullPath($Out), [System.Drawing.Imaging.ImageFormat]::Png)
$shot.Dispose(); $bmp.Dispose()
# The face keeps running in the simulator; only the monkeydo connection goes
if (-not $runner.HasExited) {
    try { & taskkill /T /F /PID $runner.Id 2>&1 | Out-Null } catch { }
}
$errors = if (Test-Path $log) { Get-Content $log | Where-Object { $_ -match 'Error|Exception|Unhandled' } } else { @() }
"$name $Device ${w}x$h -> $Out$(if ($errors) { '  RUNTIME: ' + ($errors -join ' | ') })"
