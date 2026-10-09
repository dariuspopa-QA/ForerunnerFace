# compose-showcase.ps1 -Faces <dir of 454 px face captures> -Out <store dir>
# Marketing screenshots: the real face renders inside a procedurally drawn generic watch
# (no Garmin product imagery or branding), in a calm studio style: soft backdrop, long soft
# shadow, the APEX heavy/thin wordmark and one thin accent arc echoing the face.
param([string]$Faces, [string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$dir = Join-Path $Out 'showcase'
New-Item -ItemType Directory -Force $dir | Out-Null

function C([int]$rgb, [int]$a = 255) { [System.Drawing.Color]::FromArgb($a, ($rgb -shr 16) -band 0xFF, ($rgb -shr 8) -band 0xFF, $rgb -band 0xFF) }

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

# Generic sport watch, face of radius r centred at (cx, cy)
function Watch($g, $face, $cx, $cy, $r, [int]$strap = 0x1C1C1B, [int]$metal = 0x6E6E6A) {
    $caseR = $r * 1.2
    $bandW = $r * 1.30
    # strap (top and bottom), with grooves
    foreach ($side in -1, 1) {
        $y = if ($side -lt 0) { $cy - $r * 2.6 } else { $cy + $r * 0.9 }
        $p = RoundRect ($cx - $bandW / 2) $y $bandW ($r * 1.7) ($r * 0.22)
        $rect = $p.GetBounds()
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C $strap), (C ([int]($strap + 0x0E0E0E))), 0.0
        $br.SetBlendTriangularShape(0.5)
        $g.FillPath($br, $p); $br.Dispose(); $p.Dispose()
        $pen = New-Object System.Drawing.Pen (C 0x000000 70), ([single]($r * 0.012))
        for ($k = 1; $k -le 5; $k++) {
            $gy = if ($side -lt 0) { $cy - $r * 1.05 - $k * $r * 0.24 } else { $cy + $r * 1.05 + $k * $r * 0.24 }
            $g.DrawLine($pen, [single]($cx - $bandW * 0.36), [single]$gy, [single]($cx + $bandW * 0.36), [single]$gy)
        }
        $pen.Dispose()
    }
    # lugs
    $lugArea = New-Object System.Drawing.RectangleF ([single]($cx - $r)), ([single]($cy - $r * 1.2)), ([single](2 * $r)), ([single](2.4 * $r))
    $lugBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $lugArea, (C ([int]($metal + 0x262626))), (C ([int]($metal - 0x343434))), 55.0
    foreach ($sx in -1, 1) { foreach ($sy in -1, 1) {
        # narrow horns flanking the strap edges (strap is +-0.65 r wide)
        $p = RoundRect ($cx + $sx * $r * 0.585 - $r * 0.095) ($cy + $sy * $r * 1.06 - $r * 0.15) ($r * 0.19) ($r * 0.30) ($r * 0.07)
        $g.FillPath($lugBrush, $p); $p.Dispose()
    } }
    $lugBrush.Dispose()
    # buttons
    $btn = New-Object System.Drawing.SolidBrush (C ([int]($metal - 0x181818)))
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
    # case: metal with a multi-stop gradient (light top-left, specular band, dark
    # bottom-right), a bright rim on the lit side and a dark seat under the bezel
    $caseRect = New-Object System.Drawing.RectangleF ([single]($cx - $caseR)), ([single]($cy - $caseR)), ([single](2 * $caseR)), ([single](2 * $caseR))
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $caseRect, (C $metal), (C $metal), 55.0
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend 6
    $blend.Colors = @((C ([int]($metal + 0x3C3C3C))), (C ([int]($metal + 0x101010))), (C ([int]($metal - 0x262626))),
        (C ([int]($metal + 0x2A2A2A))), (C ([int]($metal - 0x1A1A1A))), (C ([int]($metal - 0x3C3C3C))))
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
    # bezel with engraved minute marks
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
    # display: the real face render
    $img = [System.Drawing.Image]::FromFile($face)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse([single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
    $g.FillPath([System.Drawing.Brushes]::Black, $path)
    $g.SetClip($path)
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF ([single]($cx - $r)), ([single]($cy - $r)), ([single](2 * $r)), ([single](2 * $r))),
        (New-Object System.Drawing.RectangleF 2, 2, ($img.Width - 4), ($img.Height - 4)), 'Pixel')
    # glass reflection: a faint diagonal sheen across the upper left
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

function Wordmark($g, $x, $y, $size, [int]$color, [string]$tagline, [int]$tagColor) {
    $heavy = New-Object System.Drawing.Font 'Bahnschrift SemiBold Condensed', $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $thin = New-Object System.Drawing.Font 'Bahnschrift Light Condensed', $size, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $b = New-Object System.Drawing.SolidBrush (C $color)
    $g.DrawString('AP', $heavy, $b, [single]$x, [single]$y, $fmt)
    $w = $g.MeasureString('AP', $heavy, 1000, $fmt).Width
    $g.DrawString('EX', $thin, $b, [single]($x + $w + $size * 0.04), [single]$y, $fmt)
    if ($tagline) {
        $small = New-Object System.Drawing.Font 'Bahnschrift SemiLight', ($size * 0.26), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
        $tb = New-Object System.Drawing.SolidBrush (C $tagColor)
        $g.DrawString($tagline, $small, $tb, [single]($x + $size * 0.03), [single]($y + $size * 1.08), $fmt)
        $tb.Dispose(); $small.Dispose()
    }
    $b.Dispose(); $heavy.Dispose(); $thin.Dispose()
}

# A thin accent arc behind the watch, echoing the face's 270-degree arc
function AccentArc($g, $cx, $cy, $r, [int]$color, [single]$start, [single]$sweep, [single]$width) {
    $pen = New-Object System.Drawing.Pen (C $color), $width
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $g.DrawArc($pen, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), $start, $sweep)
    $pen.Dispose()
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

function F($n) { Join-Path $Faces "$n.png" }

# 1. Studio, light: the default face, editorial layout
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 0xF1EFEA 0xDCD9D2
AccentArc $g 300 290 205 0xC8FF2E 135 270 3
Shadow $g 300 290 128 70
Watch $g (F 'volt') 300 290 128
Wordmark $g 28 34 64 0x1E1E1B 'Weight, not colour.' 0x6A6A64
Save $c 500 500 'showcase-1-studio' 150

# 2. Graphite: the face large, dark backdrop, accent arc
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 0x2A2A27 0x121211
AccentArc $g 250 262 222 0xC8FF2E 150 240 2.5
Shadow $g 250 262 150 120
Watch $g (F 'volt') 250 262 150
Save $c 500 500 'showcase-2-graphite' 150

# 3. Colourways: three watches, overlapping fan
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 0xEDEBE6 0xD6D3CC
$items = @(@('ember', 120, 300, 0x7A4A3A), @('glacier', 380, 300, 0x3A4A5A), @('signal', 250, 270, 0x1C1C1B))
foreach ($it in $items) { Shadow $g $it[1] $it[2] 92 60; Watch $g (F $it[0]) $it[1] $it[2] 92 $it[3] }
Wordmark $g 28 28 46 0x1E1E1B 'One accent. Your colour.' 0x6A6A64
Save $c 500 500 'showcase-3-colourways' 150

# 4. Night: deep red-black, the red palette
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 0x1A0B09 0x070303
AccentArc $g 250 262 222 0xFF4A3D 150 240 2.5
Shadow $g 250 262 150 140
Watch $g (F 'night') 250 262 150 0x1A1514 0x5E5A58
Wordmark $g 28 28 40 0xFF4A3D 'Night mode' 0xB3392E
Save $c 500 500 'showcase-4-night' 150

# 5. Always-on: muted, low light
$c = NewCanvas 500 500; $g = $c[1]
Backdrop $g 500 500 0x1E1E1C 0x0B0B0A
Shadow $g 250 262 150 120
Watch $g (F 'aod') 250 262 150
Wordmark $g 28 28 40 0xB0B0AA 'Always-on' 0x6A6A64
Save $c 500 500 'showcase-5-always-on' 150

# Hero 1440 x 720 in the same style
$c = NewCanvas 1440 720; $g = $c[1]
Backdrop $g 1440 720 0xF1EFEA 0xD8D5CE
AccentArc $g 1010 372 300 0xC8FF2E 135 270 4
Shadow $g 1010 372 200 70
Watch $g (F 'volt') 1010 372 200
Wordmark $g 120 230 150 0x1E1E1B 'Weight, not colour.' 0x6A6A64
Save $c 1440 720 'showcase-hero-1440x720' 1024
