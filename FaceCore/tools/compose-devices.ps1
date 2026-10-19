# compose-devices.ps1 -Faces <dir> -Out <store dir>
# One 500 x 500 store screenshot per screen type (face + the watches that use it), and an
# overview with every screen at its true relative size. <dir> holds the round display
# captures named by product id (capture-screens.ps1 takes them and runs this).
# (Copied from ApexFace/store/tools/compose-devices.ps1.)
param([string]$Faces, [string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$dir = Join-Path $Out 'watches'
New-Item -ItemType Directory -Force $dir | Out-Null

$graphite = [System.Drawing.Color]::FromArgb(0x1E, 0x1E, 0x1B)
$bezel = [System.Drawing.Color]::FromArgb(0x3A, 0x3A, 0x35)
$chalk = [System.Drawing.Color]::FromArgb(0xF4, 0xF4, 0xEF)
$dim = [System.Drawing.Color]::FromArgb(0xB0, 0xB0, 0xAA)

# product id captured, screen, watches using that screen
$types = @(
    @('fr255s', 218, 'MIP', 'Forerunner 255S'),
    @('fenix7s', 240, 'MIP', 'fenix 7S / 7S Pro'),
    @('fenix7', 260, 'MIP', 'fenix 7 / 7 Pro / 8 Solar 47 / 9 Pro Solar 47 · Forerunner 255 / 955'),
    @('enduro3', 280, 'MIP', 'fenix 7X / 7X Pro / 8 Solar 51 / 9 Pro Solar 51 · Enduro 3'),
    @('venu2s', 360, 'AMOLED', 'Venu 2S · Forerunner 265S'),
    @('fr165', 390, 'AMOLED', 'Forerunner 70 / 165 / 170 / 570 42 · Venu 3S / 4 41 · vivoactive 5 / 6 · MARQ Gen 2 · Instinct 3 45 · Approach · Descent'),
    @('fr265', 416, 'AMOLED', 'Forerunner 265 · Venu 2 / 2 Plus · epix Gen 2 · fenix 8 43 / 9 43 / E · Instinct 3 50 · D2'),
    @('fr970', 454, 'AMOLED', 'Forerunner 570 47 / 965 / 970 · Venu 3 / 4 45 · fenix 8 47 / 9 47 · epix Pro 51 · D2 Mach 2'),
    @('fenix9pro51mm', 466, 'AMOLED', 'fenix 9 Pro 51')
)

function NewCanvas($w, $h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear($graphite)
    return @($bmp, $g)
}

function DrawFace($g, $file, $cx, $cy, $d) {
    $img = [System.Drawing.Image]::FromFile($file)
    $ring = [single]([Math]::Max(2, $d * 0.02))
    $pen = New-Object System.Drawing.Pen $bezel, $ring
    $g.DrawEllipse($pen, [single]($cx - $d / 2 - $ring / 2), [single]($cy - $d / 2 - $ring / 2), [single]($d + $ring), [single]($d + $ring))
    $pen.Dispose()
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse([single]($cx - $d / 2), [single]($cy - $d / 2), [single]$d, [single]$d)
    $g.SetClip($path)
    $g.FillPath([System.Drawing.Brushes]::Black, $path)
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF ([single]($cx - $d / 2)), ([single]($cy - $d / 2)), ([single]$d), ([single]$d)),
        (New-Object System.Drawing.RectangleF 1, 1, ($img.Width - 2), ($img.Height - 2)), 'Pixel')
    $g.ResetClip()
    $img.Dispose()
}

function SavePng($bmp, $path, $limitKB) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $kb = [int]((Get-Item $path).Length / 1024)
    if ($kb -gt $limitKB) { throw "$path is $kb KB (limit $limitKB)" }
    "$path  $kb KB"
}

$title = New-Object System.Drawing.Font 'Bahnschrift SemiBold Condensed', 22, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$small = New-Object System.Drawing.Font 'Bahnschrift SemiLight', 15, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$center = New-Object System.Drawing.StringFormat
$center.Alignment = 'Center'
$center.LineAlignment = 'Near'
$chalkBrush = New-Object System.Drawing.SolidBrush $chalk
$dimBrush = New-Object System.Drawing.SolidBrush $dim

# ---- One screenshot per screen type ------------------------------------------
foreach ($t in $types) {
    $c = NewCanvas 500 500
    $g = $c[1]
    DrawFace $g (Join-Path $Faces "$($t[0]).png") 250 196 352
    $g.DrawString("$($t[1]) x $($t[1]) px  ·  $($t[2])", $title, $chalkBrush, (New-Object System.Drawing.RectangleF 20, 390, 460, 30), $center)
    $g.DrawString($t[3], $small, $dimBrush, (New-Object System.Drawing.RectangleF 30, 422, 440, 70), $center)
    $g.Dispose()
    SavePng $c[0] (Join-Path $dir ("screen-{0}-{1}.png" -f $t[1], $t[2].ToLower())) 150
    $c[0].Dispose()
}

# ---- Overview: every screen at its true relative size --------------------------
$c = NewCanvas 500 500
$g = $c[1]
$cell = 500 / 3.0
$label = New-Object System.Drawing.Font 'Bahnschrift SemiLight', 13, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
for ($i = 0; $i -lt $types.Count; $i++) {
    $t = $types[$i]
    $cx = ($i % 3 + 0.5) * $cell
    $cy = [Math]::Floor($i / 3) * $cell + 72
    $d = 128 * $t[1] / 466.0
    DrawFace $g (Join-Path $Faces "$($t[0]).png") $cx $cy $d
    $g.DrawString("$($t[1]) px $($t[2])", $label, $dimBrush, (New-Object System.Drawing.RectangleF ([single]($cx - 80)), ([single]($cy + 72)), 160, 20), $center)
}
$g.Dispose()
SavePng $c[0] (Join-Path $dir 'screens-overview.png') 150
$c[0].Dispose()
