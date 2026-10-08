# capture.ps1 -Prg bin\x.prg -Out raw\x.png : runs the prg in the simulator and saves the window image.
param([string]$Prg, [string]$Out, [int]$Wait = 6)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Win {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
[Win]::SetProcessDPIAware() | Out-Null
$sdk = "$env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"
Get-Process monkeydo, java -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*java*' -and $_.CommandLine -like '*monkeydo*' } | Stop-Process -Force -ErrorAction SilentlyContinue
$p = Start-Process -FilePath "$sdk\bin\monkeydo.bat" -ArgumentList $Prg, 'fr970' -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\shot_out.txt" -RedirectStandardError "$env:TEMP\shot_err.txt"
Start-Sleep -Seconds $Wait
$sim = Get-Process simulator | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $sim.MainWindowHandle
$r = New-Object Win+RECT
[Win]::GetWindowRect($h, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[Win]::PrintWindow($h, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc)
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"saved $Out $($bmp.Width)x$($bmp.Height)"
$bmp.Dispose()
Get-Content "$env:TEMP\shot_err.txt" -ErrorAction SilentlyContinue | Select-Object -Last 5
