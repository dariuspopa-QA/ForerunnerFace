# aod-optimize.ps1 [-Hours "10,16,23"] [-Iterations 1500] : searches Always-On shift patterns (8 steps,
# |offset| <= 10, every 4-minute window spread >= 14 px both ways) that minimise the pixels lit
# > 3 consecutive minutes, on an offline render of the Always-On time for minutes 00-59 (454 px).
# Starts from AOD_SHIFTS in source/FaceView.mc; copy a better result there and confirm it with
# ApexFace\tools\aod-burnin.ps1 on real simulator frames. Adapted from ApexFace.
param([string]$Hours = "10,16,23", [int]$Iterations = 1500, [int]$Seed = 1)
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
# Always-On time: hours and minutes both in Space Grotesk Light 112 px, -5 px tracking, 6 px gap
$pfc = New-Object System.Drawing.Text.PrivateFontCollection; $pfc.AddFontFile("$src\SpaceGrotesk-Light.ttf")
function StyleFor($f) { foreach ($s in 'Regular', 'Bold') { if ($f.IsStyleAvailable([System.Drawing.FontStyle]$s)) { return [System.Drawing.FontStyle]$s } } }
$font = New-Object System.Drawing.Font $pfc.Families[0], 112, (StyleFor $pfc.Families[0]), ([System.Drawing.GraphicsUnit]::Pixel)
$fmt = [System.Drawing.StringFormat]::GenericTypographic
$margin = 12; $W = 420; $H = 200

function Tracked($g, [string]$text) {
    $w = 0.0
    foreach ($ch in $text.ToCharArray()) { $w += $g.MeasureString([string]$ch, $font, 1000, $fmt).Width }
    return $w - 5 * ($text.Length - 1)
}
function Draw($g, [string]$text, [single]$x) {
    foreach ($ch in $text.ToCharArray()) {
        $g.DrawString([string]$ch, $font, [System.Drawing.Brushes]::White, $x, [single]30, $fmt)
        $x += $g.MeasureString([string]$ch, $font, 1000, $fmt).Width - 5
    }
}

$hourSets = @()
foreach ($hr in $Hours.Split(',')) {
    $frames = New-Object 'System.Collections.Generic.List[bool[]]'
    for ($m = 0; $m -lt 60; $m++) {
        $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp); $g.TextRenderingHint = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Black)
        $hh = $hr.Trim(); $mm = $m.ToString('00')
        $wh = Tracked $g $hh; $wm = Tracked $g $mm
        $left = [single]($W / 2 - ($wh + 6 + $wm) / 2)
        Draw $g $hh $left
        Draw $g $mm ([single]($left + $wh + 6))
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
