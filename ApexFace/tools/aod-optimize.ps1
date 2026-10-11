# aod-optimize.ps1 [-Hours "10,23"] [-Iterations 1500] : searches Always-On shift patterns (8 steps,
# |offset| <= 10, every 4-minute window spread >= 14 px both ways) that minimise the pixels lit
# > 3 consecutive minutes, on an offline render of the time for minutes 00-59 (fr970, 454 px).
# Starts from the shared pattern in FaceCore/kit/FaceKit.mc (AOD_SHIFTS); copy a better result there
# and confirm it with tools\aod-burnin.ps1 on real simulator frames. The hour digits never
# score (the spread covers their strokes), so the result is the same for every hour.
param([string]$Hours = '10', [int]$Iterations = 1500, [int]$Seed = 1)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Language CSharp @'
using System;
using System.Collections.Generic;
public static class Burn {
    // frames[f][y*w+x]: unshifted lit masks with a margin; pattern: dx,dy per step
    public static int Score(List<bool[]> frames, int w, int h, int[] dx, int[] dy, int margin, int limit) {
        int n = frames.Count, steps = dx.Length, over = 0;
        for (int y = margin; y < h - margin; y++)
        for (int x = margin; x < w - margin; x++) {
            int run = 0, best = 0;
            for (int k = 0; k < n; k++) {
                int s = k % steps;
                if (frames[k][(y - dy[s]) * w + (x - dx[s])]) { run++; if (run > best) best = run; } else run = 0;
            }
            if (best > limit) over++;
        }
        return over;
    }
    public static bool Spread(int[] dx, int[] dy, int window, int min) {
        int n = dx.Length;
        for (int s = 0; s < n; s++) {
            int lx = 99, hx = -99, ly = 99, hy = -99;
            for (int k = 0; k < window; k++) { int i = (s + k) % n;
                lx = Math.Min(lx, dx[i]); hx = Math.Max(hx, dx[i]); ly = Math.Min(ly, dy[i]); hy = Math.Max(hy, dy[i]); }
            if (hx - lx < min || hy - ly < min) return false;
        }
        return true;
    }
}
'@
$src = Join-Path $PSScriptRoot 'fonts'
$pfcL = New-Object System.Drawing.Text.PrivateFontCollection; $pfcL.AddFontFile("$src\BarlowCondensed-Light.ttf")
$pfcT = New-Object System.Drawing.Text.PrivateFontCollection; $pfcT.AddFontFile("$src\BarlowCondensed-ExtraLight.ttf")
function StyleFor($f) { foreach ($s in 'Regular', 'Bold') { if ($f.IsStyleAvailable([System.Drawing.FontStyle]$s)) { return [System.Drawing.FontStyle]$s } } }
$fh = New-Object System.Drawing.Font $pfcL.Families[0], 164, (StyleFor $pfcL.Families[0]), ([System.Drawing.GraphicsUnit]::Pixel)
$fm = New-Object System.Drawing.Font $pfcT.Families[0], 164, (StyleFor $pfcT.Families[0]), ([System.Drawing.GraphicsUnit]::Pixel)
$fmt = [System.Drawing.StringFormat]::GenericTypographic
$margin = 12; $X0 = 40; $Y0 = 80; $W = 400; $H = 230

$hourSets = @()
foreach ($hr in $Hours.Split(',')) {
    $frames = New-Object 'System.Collections.Generic.List[bool[]]'
    for ($m = 0; $m -lt 60; $m++) {
        $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp); $g.TextRenderingHint = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Black)
        $hh = ([int]$hr).ToString('00'); $mm = $m.ToString('00')
        $wh = $g.MeasureString($hh, $fh, 1000, $fmt).Width
        $g.DrawString($hh, $fh, [System.Drawing.Brushes]::White, [single](222 - $wh - $X0), [single](100 - $Y0), $fmt)
        $g.DrawString($mm, $fm, [System.Drawing.Brushes]::White, [single](232 - $X0), [single](100 - $Y0), $fmt)
        $g.Dispose()
        $data = $bmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $W, $H), 'ReadOnly', $bmp.PixelFormat)
        $bytes = New-Object byte[] ($data.Stride * $H)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        $bmp.UnlockBits($data); $bmp.Dispose()
        $mask = New-Object bool[] ($W * $H)
        for ($i = 0; $i -lt $W * $H; $i++) { $mask[$i] = $bytes[$i * 4 + 1] -gt 12 }
        $frames.Add($mask)
    }
    $hourSets += , $frames
}

function Total([int[]]$dx, [int[]]$dy) {
    $t = 0
    foreach ($fs in $hourSets) { $t += [Burn]::Score($fs, $W, $H, $dx, $dy, $margin, 3) }
    return $t
}

$cur = @{ dx = [int[]](-5, 9, -10, 9, -6, 8, -10, 9); dy = [int[]](-10, -10, 3, 10, -6, -10, 3, 10) }
$curScore = Total $cur.dx $cur.dy
"start (current pattern): $curScore"
$rng = New-Object System.Random $Seed
$best = $cur; $bestScore = $curScore
for ($it = 0; $it -lt $Iterations; $it++) {
    $dx = [int[]]$best.dx.Clone(); $dy = [int[]]$best.dy.Clone()
    $changes = $rng.Next(1, 3)
    for ($c = 0; $c -lt $changes; $c++) {
        $i = $rng.Next(0, 8)
        if ($rng.Next(0, 2) -eq 0) { $dx[$i] = $rng.Next(-10, 11) } else { $dy[$i] = $rng.Next(-10, 11) }
    }
    if (-not [Burn]::Spread($dx, $dy, 4, 14)) { continue }
    $sc = Total $dx $dy
    if ($sc -le $bestScore) {
        if ($sc -lt $bestScore) { "it $it : $sc  dx=$($dx -join ',') dy=$($dy -join ',')" }
        $best = @{ dx = $dx; dy = $dy }; $bestScore = $sc
        if ($sc -eq 0) { break }
    }
}
"BEST $bestScore  dx=$($best.dx -join ',') dy=$($best.dy -join ',')"
