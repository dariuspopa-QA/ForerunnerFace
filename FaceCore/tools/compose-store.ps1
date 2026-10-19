# Connect IQ Store images for a face, from its simulator captures (shot.ps1) in
# <face>\store\faces\<name>.png and its settings in <face>\store\store-config.ps1:
#
#   store-icon-500      the face on a solid backdrop (500 x 500)
#   cover-500           the face with the wordmark (500 x 500)
#   screenshot-<n>-*    each capture in $Store.Shots on graphite (500 x 500)
#   showcase-1..5       the face in a procedurally drawn generic watch (no Garmin product
#                       imagery or branding): studio, colourways, palette grid, graphite,
#                       always-on (500 x 500)
#   hero-1440x720       wordmark, tagline, colour swatches and the watch; -no-text without
#                       the tagline (language neutral)
#
#   powershell -ExecutionPolicy Bypass -File FaceCore\tools\compose-store.ps1 -Face Meridian
#
# Same layout as ApexFace's and Bloom's store images (generalised from
# Bloom/store/tools/compose.ps1). PNG when it fits the store's size limit, else JPEG.
param([Parameter(Mandatory)][string]$Face)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = (Resolve-Path (Join-Path $repo $Face)).Path
$dir = Join-Path $root 'store'
$Faces = Join-Path $dir 'faces'
. (Join-Path $dir 'store-config.ps1')

# Defaults for keys a face leaves out
$defaults = @{
    Dark = $false; Light = @(0xF4EFEC, 0xDDD5D1); Night = @(0x2A282A, 0x111011); Graphite = 0x1E1D1E
    Ink = 0x1E1D1E; Paper = 0xF3F1EC; Muted = 0x6E6A66; Glow = 0x888888; Strap = 0x1C1C1B; Metal = 0x6E6E6A
}
foreach ($k in $defaults.Keys) { if (-not $Store.ContainsKey($k)) { $Store[$k] = $defaults[$k] } }

function C([int]$rgb, [int]$a = 255) { [System.Drawing.Color]::FromArgb($a, ($rgb -shr 16) -band 0xFF, ($rgb -shr 8) -band 0xFF, $rgb -band 0xFF) }

# Old Store images go first, so a shot list that got shorter leaves nothing behind
Get-ChildItem $dir -File | Where-Object { $_.Name -match '^(store-icon|cover|screenshot-|showcase-|hero-)' } | Remove-Item

$SS = 2   # supersampling: draw at 2x, downscale for smooth edges

function NewCanvas($w, $h) {
    $bmp = New-Object System.Drawing.Bitmap ($w * $SS), ($h * $SS), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.ScaleTransform($SS, $SS)
    return @($bmp, $g)
}

function Backdrop($g, $w, $h, [int]$top, [int]$bottom) {
    $rect = New-Object System.Drawing.RectangleF 0, 0, $w, $h
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C $top), (C $bottom), 90.0
    $g.FillRectangle($br, $rect)
    $br.Dispose()
}

# Soft shadow: stacked translucent ellipses, offset down-right
function Shadow($g, $cx, $cy, $r, [int]$alpha) {
    for ($i = 12; $i -ge 1; $i--) {
        $rr = $r + $i * 6
        $b = New-Object System.Drawing.SolidBrush (C 0x000000 ([int]($alpha / 12)))
        $g.FillEllipse($b, [single]($cx - $rr + $r * 0.10), [single]($cy - $rr * 0.97 + $r * 0.16), [single](2 * $rr), [single](2 * $rr * 0.97))
        $b.Dispose()
    }
}

function RoundRect($x, $y, $w, $h, $rad) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $rad
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Clamp([int]$v) { [Math]::Max(0, [Math]::Min(255, $v)) }
function Shade([int]$rgb, [int]$d) {
    ((Clamp ((($rgb -shr 16) -band 0xFF) + $d)) -shl 16) -bor ((Clamp ((($rgb -shr 8) -band 0xFF) + $d)) -shl 8) -bor (Clamp (($rgb -band 0xFF) + $d))
}

# Generic sport watch, display of radius r centred at (cx, cy)
function Watch($g, $face, $cx, $cy, $r, [int]$strap = $Store.Strap, [int]$metal = $Store.Metal) {
    $caseR = $r * 1.2
    $bandW = $r * 1.30
    foreach ($side in -1, 1) {
        $y = if ($side -lt 0) { $cy - $r * 2.6 } else { $cy + $r * 0.9 }
        $p = RoundRect ($cx - $bandW / 2) $y $bandW ($r * 1.7) ($r * 0.22)
        $rect = $p.GetBounds()
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C $strap), (C (Shade $strap 14)), 0.0
        $br.SetBlendTriangularShape(0.5)
        $g.FillPath($br, $p); $br.Dispose(); $p.Dispose()
        $pen = New-Object System.Drawing.Pen (C 0x000000 70), ([single]($r * 0.012))
        for ($k = 1; $k -le 5; $k++) {
            $gy = if ($side -lt 0) { $cy - $r * 1.05 - $k * $r * 0.24 } else { $cy + $r * 1.05 + $k * $r * 0.24 }
            $g.DrawLine($pen, [single]($cx - $bandW * 0.36), [single]$gy, [single]($cx + $bandW * 0.36), [single]$gy)
        }
        $pen.Dispose()
    }
    $lugArea = New-Object System.Drawing.RectangleF ([single]($cx - $r)), ([single]($cy - $r * 1.2)), ([single](2 * $r)), ([single](2.4 * $r))
    $lugBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $lugArea, (C (Shade $metal 38)), (C (Shade $metal -52)), 55.0
    foreach ($sx in -1, 1) { foreach ($sy in -1, 1) {
        $p = RoundRect ($cx + $sx * $r * 0.585 - $r * 0.095) ($cy + $sy * $r * 1.06 - $r * 0.15) ($r * 0.19) ($r * 0.30) ($r * 0.07)
        $g.FillPath($lugBrush, $p); $p.Dispose()
    } }
    $lugBrush.Dispose()
    $btn = New-Object System.Drawing.SolidBrush (C (Shade $metal -24))
    foreach ($a in -35, 35, 145, 215) {
        $rad = [Math]::PI * $a / 180
        $bx = $cx + [Math]::Cos($rad) * $caseR * 0.98
        $by = $cy + [Math]::Sin($rad) * $caseR * 0.98
        $g.TranslateTransform([single]$bx, [single]$by); $g.RotateTransform([single]$a)
        $p = RoundRect (-$r * 0.02) (-$r * 0.07) ($r * 0.14) ($r * 0.14) ($r * 0.03)
        $g.FillPath($btn, $p); $p.Dispose()
        $g.ResetTransform(); $g.ScaleTransform($SS, $SS)
    }
    $btn.Dispose()
    $caseRect = New-Object System.Drawing.RectangleF ([single]($cx - $caseR)), ([single]($cy - $caseR)), ([single](2 * $caseR)), ([single](2 * $caseR))
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $caseRect, (C $metal), (C $metal), 55.0
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend 6
    $blend.Colors = @((C (Shade $metal 60)), (C (Shade $metal 16)), (C (Shade $metal -38)), (C (Shade $metal 42)), (C (Shade $metal -26)), (C (Shade $metal -60)))
    $blend.Positions = @(0.0, 0.28, 0.48, 0.58, 0.78, 1.0)
    $br.InterpolationColors = $blend
    $g.FillEllipse($br, $caseRect); $br.Dispose()
    $pen = New-Object System.Drawing.Pen (C 0xFFFFFF 90), ([single]($r * 0.014))
    $g.DrawArc($pen, $caseRect, 195, 110); $pen.Dispose()
    $pen = New-Object System.Drawing.Pen (C 0x000000 90), ([single]($r * 0.014))
    $g.DrawArc($pen, $caseRect, 15, 110); $pen.Dispose()
    $seatR = $r * 1.145
    $b = New-Object System.Drawing.SolidBrush (C 0x0B0B0A)
    $g.FillEllipse($b, [single]($cx - $seatR), [single]($cy - $seatR), [single](2 * $seatR), [single](2 * $seatR)); $b.Dispose()
    $bezR = $r * 1.13
    $b = New-Object System.Drawing.SolidBrush (C 0x161615)
    $g.FillEllipse($b, [single]($cx - $bezR), [single]($cy - $bezR), [single](2 * $bezR), [single](2 * $bezR)); $b.Dispose()
    for ($m = 0; $m -lt 60; $m++) {
        $a = [Math]::PI * $m / 30
        $len = if ($m % 5 -eq 0) { 0.07 } else { 0.035 }
        $pen = New-Object System.Drawing.Pen (C 0x8A8A86 $(if ($m % 5 -eq 0) { 220 } else { 120 })), ([single]($r * $(if ($m % 5 -eq 0) { 0.014 } else { 0.007 })))
        $x1 = $cx + [Math]::Sin($a) * $r * 1.105; $y1 = $cy - [Math]::Cos($a) * $r * 1.105
        $x2 = $cx + [Math]::Sin($a) * $r * (1.105 - $len); $y2 = $cy - [Math]::Cos($a) * $r * (1.105 - $len)
        $g.DrawLine($pen, [single]$x1, [single]$y1, [single]$x2, [single]$y2); $pen.Dispose()
    }
    $img = [System.Drawing.Image]::FromFile($face)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse([single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
    $g.FillPath([System.Drawing.Brushes]::Black, $path)
    $g.SetClip($path)
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF ([single]($cx - $r)), ([single]($cy - $r)), ([single](2 * $r)), ([single](2 * $r))),
        (New-Object System.Drawing.RectangleF 2, 2, ($img.Width - 4), ($img.Height - 4)), 'Pixel')
    $sheen = New-Object System.Drawing.Drawing2D.GraphicsPath
    $sheen.AddEllipse([single]($cx - $r * 1.5), [single]($cy - $r * 2.05), [single]($r * 2.2), [single]($r * 1.9))
    $sb = New-Object System.Drawing.Drawing2D.PathGradientBrush $sheen
    $sb.CenterColor = C 0xFFFFFF 26
    $sb.SurroundColors = @(C 0xFFFFFF 0)
    $g.FillPath($sb, $sheen); $sb.Dispose(); $sheen.Dispose()
    $g.ResetClip()
    $pen = New-Object System.Drawing.Pen (C 0x000000 200), ([single]($r * 0.02))
    $g.DrawEllipse($pen, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $pen.Dispose()
    $img.Dispose(); $path.Dispose()
}

function Save($c, $w, $h, $name, $limitKB) {
    $c[1].Dispose()
    $small = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($small)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
    $g.DrawImage($c[0], 0, 0, $w, $h); $g.Dispose(); $c[0].Dispose()
    $png = Join-Path $dir "$name.png"
    $small.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
    if ((Get-Item $png).Length -le $limitKB * 1024) { "$png  $([int]((Get-Item $png).Length / 1024)) KB"; $small.Dispose(); return }
    Remove-Item $png
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    foreach ($q in 94, 92, 90, 88, 85, 82, 78) {
        $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$q)
        $jpg = Join-Path $dir "$name.jpg"
        $small.Save($jpg, $codec, $ep)
        if ((Get-Item $jpg).Length -le $limitKB * 1024) { "$jpg  $([int]((Get-Item $jpg).Length / 1024)) KB (q$q)"; $small.Dispose(); return }
    }
    throw "$name does not fit $limitKB KB"
}

# ---- The face's wordmark: pieces of text, each in one of the face's own fonts ------------

$collections = @{}
# A piece's font: a .ttf from <face>\tools\fonts, or an installed font family by name
function FontFile([string]$ttf, [single]$size) {
    if ($ttf -notmatch '\.ttf$') {
        return New-Object System.Drawing.Font $ttf, $size, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    }
    if (-not $collections.ContainsKey($ttf)) {
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        $pfc.AddFontFile((Join-Path $root "tools\fonts\$ttf"))
        $collections[$ttf] = $pfc
    }
    $fam = $collections[$ttf].Families[0]
    $style = [System.Drawing.FontStyle]::Regular
    foreach ($s in 'Regular', 'Bold', 'Italic', 'BoldItalic') {
        if ($fam.IsStyleAvailable([System.Drawing.FontStyle]$s)) { $style = [System.Drawing.FontStyle]$s; break }
    }
    New-Object System.Drawing.Font $fam, $size, $style, ([System.Drawing.GraphicsUnit]::Pixel)
}

$fmt = [System.Drawing.StringFormat]::GenericTypographic.Clone()
$fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

function WordWidth($g, [single]$size) {
    $w = 0
    foreach ($piece in $Store.Word) {
        $f = FontFile $piece[1] $size
        $w += $g.MeasureString($piece[0], $f, 4000, $fmt).Width
        $f.Dispose()
    }
    return $w
}

# Wordmark with its left edge at x (or centred on x with -Center), cap top near y
function Wordmark($g, [single]$x, [single]$y, [single]$size, [int]$color, [switch]$Center) {
    if ($Center) { $x -= (WordWidth $g $size) / 2 }
    $b = New-Object System.Drawing.SolidBrush (C $color)
    foreach ($piece in $Store.Word) {
        $f = FontFile $piece[1] $size
        $g.DrawString($piece[0], $f, $b, $x, $y, $fmt)
        $x += $g.MeasureString($piece[0], $f, 4000, $fmt).Width
        $f.Dispose()
    }
    $b.Dispose()
}

function Tagline($g, [single]$x, [single]$y, [single]$size, [int]$color, [string]$text) {
    $f = New-Object System.Drawing.Font 'Segoe UI', $size, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $b = New-Object System.Drawing.SolidBrush (C $color)
    $g.DrawString($text, $f, $b, $x, $y, $fmt)
    $b.Dispose(); $f.Dispose()
}

function Swatches($g, $x, $y, $d, $gap) {
    for ($i = 0; $i -lt $Store.Swatches.Count; $i++) {
        $b = New-Object System.Drawing.SolidBrush (C $Store.Swatches[$i])
        $g.FillEllipse($b, [single]($x + $i * ($d + $gap)), [single]$y, [single]$d, [single]$d); $b.Dispose()
    }
}

function F($n) {
    $p = Join-Path $Faces "$n.png"
    if (-not (Test-Path $p)) { throw "missing capture $p" }
    return $p
}

# The round display alone with a thin bezel ring (plain screenshots, icon)
function FlatFace($g, $face, $cx, $cy, $d) {
    $img = [System.Drawing.Image]::FromFile($face)
    $ring = [single]($d * 0.02)
    $pen = New-Object System.Drawing.Pen (C 0x3A383A), $ring
    $g.DrawEllipse($pen, [single]($cx - $d / 2 - $ring / 2), [single]($cy - $d / 2 - $ring / 2), [single]($d + $ring), [single]($d + $ring))
    $pen.Dispose()
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse([single]($cx - $d / 2), [single]($cy - $d / 2), [single]$d, [single]$d)
    $g.FillPath([System.Drawing.Brushes]::Black, $path)
    $g.SetClip($path)
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF ([single]($cx - $d / 2)), ([single]($cy - $d / 2)), ([single]$d), ([single]$d)),
        (New-Object System.Drawing.RectangleF 2, 2, ($img.Width - 4), ($img.Height - 4)), 'Pixel')
    $g.ResetClip()
    $path.Dispose(); $img.Dispose()
}

function Solid($w, $h, [int]$color) {
    $c = NewCanvas $w $h
    $b = New-Object System.Drawing.SolidBrush (C $color)
    $c[1].FillRectangle($b, 0, 0, $w, $h); $b.Dispose()
    return $c
}

function Glow($g, $cx, $cy, $r, [int]$color, [int]$alpha) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddEllipse([single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
    $b = New-Object System.Drawing.Drawing2D.PathGradientBrush $p
    $b.CenterColor = C $color $alpha
    $b.SurroundColors = @(C $color 0)
    $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
}

# Studio backdrop and the colours on it: light by default, dark ($Store.Dark) for faces
# that read better on dark (the Shop Floor family)
$bgTop = if ($Store.Dark) { $Store.Night[0] } else { $Store.Light[0] }
$bgBottom = if ($Store.Dark) { $Store.Night[1] } else { $Store.Light[1] }
$wordColor = if ($Store.Dark) { $Store.Paper } else { $Store.Ink }

# ---- Store icon: 500 x 500, solid (not black) background, <= 300 KB --------------------
$c = Solid 500 500 $Store.Graphite
FlatFace $c[1] (F $Store.Hero) 250 250 450
Save $c 500 500 'store-icon-500' 300

# ---- Cover: 500 x 500 ---------------------------------------------------------------------
$c = Solid 500 500 $Store.Graphite
FlatFace $c[1] (F $Store.Hero) 250 205 350
$size = 62.0
while ((WordWidth $c[1] $size) -gt 440) { $size -= 2 }
Wordmark $c[1] 250 400 $size $Store.Paper -Center
Save $c 500 500 'cover-500' 300

# ---- Plain screenshots: 500 x 500, <= 150 KB ----------------------------------------------
for ($i = 0; $i -lt $Store.Shots.Count; $i++) {
    $c = Solid 500 500 $Store.Graphite
    FlatFace $c[1] (F $Store.Shots[$i]) 250 250 440
    Save $c 500 500 ("screenshot-{0}-{1}" -f ($i + 1), $Store.Shots[$i]) 150
}

# ---- Showcase ---------------------------------------------------------------------------
# 1. Studio: the default face, wordmark and tagline
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 $bgTop $bgBottom
Glow $g 300 290 230 $Store.Glow 70
Shadow $g 300 290 128 70
Watch $g (F $Store.Hero) 300 290 128
$size = 52.0
while ((WordWidth $g $size) -gt 300) { $size -= 2 }
Wordmark $g 24 24 $size $wordColor
Tagline $g 26 (24 + $size * 1.12) ($size * 0.30) $Store.Muted $Store.Tagline
Save $c 500 500 'showcase-1-studio' 150

# 2. Colourways: three watches in a fan
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 $bgTop $bgBottom
Glow $g 250 300 260 $Store.Glow 40
$items = @(@($Store.Trio[0], 120, 305, 0x34404E), @($Store.Trio[1], 380, 305, 0x3A4A40), @($Store.Trio[2], 250, 275, $Store.Strap))
foreach ($it in $items) { Shadow $g $it[1] $it[2] 92 60; Watch $g (F $it[0]) $it[1] $it[2] 92 $it[3] }
Save $c 500 500 'showcase-2-colourways' 150

# 3. Variations: four faces, flat, with the colour swatches
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 0x242224 0x0E0D0E
$grid = @(@($Store.Quad[0], 140, 160), @($Store.Quad[1], 360, 160), @($Store.Quad[2], 140, 370), @($Store.Quad[3], 360, 370))
foreach ($it in $grid) { FlatFace $g (F $it[0]) $it[1] $it[2] 190 }
$n = $Store.Swatches.Count
Swatches $g (250 - ($n * 14 + ($n - 1) * 16) / 2) 472 14 16
Save $c 500 500 'showcase-3-variations' 150

# 4. Graphite: the face large, glow in its colour
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 $Store.Night[0] $Store.Night[1]
Glow $g 250 262 250 $Store.LargeGlow 60
Shadow $g 250 262 150 120
Watch $g (F $Store.Large) 250 262 150
Save $c 500 500 'showcase-4-graphite' 150

# 5. Always-on (AMOLED) or the MIP screen: muted, low light
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 0x1E1D1E 0x0B0B0B
Shadow $g 250 262 150 120
Watch $g (F $Store.Aod) 250 262 150
$size = 40.0
while ((WordWidth $g $size) -gt 260) { $size -= 2 }
Wordmark $g 28 22 $size 0xB9B6B0
Tagline $g 30 (22 + $size * 1.12) ($size * 0.36) 0x6E6A66 $Store.AodLabel
Save $c 500 500 'showcase-5-always-on' 150

# ---- Hero: 1440 x 720, English tagline and a language-neutral version ------------------
function Hero([bool]$withText, [string]$name) {
    $c = NewCanvas 1440 720; $g = $c[1]
    Backdrop $g 1440 720 $bgTop $bgBottom
    Glow $g 1010 372 420 $Store.Glow 70
    Shadow $g 1010 372 200 70
    Watch $g (F $Store.Hero) 1010 372 200
    $size = 150.0
    while ((WordWidth $g $size) -gt 640) { $size -= 4 }
    if ($withText) {
        Wordmark $g 116 (300 - $size * 0.55) $size $wordColor
        Tagline $g 122 (300 + $size * 0.62) ($size * 0.24) $Store.Muted $Store.Tagline
        Swatches $g 126 470 22 18
    } else {
        Wordmark $g 116 (330 - $size * 0.55) $size $wordColor
        Swatches $g 126 450 22 18
    }
    Save $c 1440 720 $name 1024
}
Hero $true 'hero-1440x720'
Hero $false 'hero-1440x720-no-text'
