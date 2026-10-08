# compose.ps1 -Faces <dir of 454 px face crops> -Out <store dir>
# Builds the Connect IQ Store images: store icon (500x500), screenshots (500x500)
# and hero image (1440x720).
param([string]$Faces, [string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null

$graphite = [System.Drawing.Color]::FromArgb(0x1E, 0x1E, 0x1B)   # solid, not black (store icon rule)
$bezel = [System.Drawing.Color]::FromArgb(0x3A, 0x3A, 0x35)
$chalk = [System.Drawing.Color]::FromArgb(0xF4, 0xF4, 0xEF)
$dim = [System.Drawing.Color]::FromArgb(0xB0, 0xB0, 0xAA)

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

# Round face (diameter d) centred at (cx, cy) with a thin bezel ring.
function DrawFace($g, $name, $cx, $cy, $d) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $Faces "$name.png"))
    $ring = [single]($d * 0.02)
    $pen = New-Object System.Drawing.Pen $bezel, $ring
    $g.DrawEllipse($pen, [single]($cx - $d / 2 - $ring / 2), [single]($cy - $d / 2 - $ring / 2), [single]($d + $ring), [single]($d + $ring))
    $pen.Dispose()
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse([single]($cx - $d / 2), [single]($cy - $d / 2), [single]$d, [single]$d)
    $g.SetClip($path)
    $g.FillPath([System.Drawing.Brushes]::Black, $path)
    # drop the outermost pixel of the capture (bezel bleed) by drawing 1 px inset
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF ([single]($cx - $d / 2)), ([single]($cy - $d / 2)), ([single]$d), ([single]$d)),
        (New-Object System.Drawing.RectangleF 1, 1, 452, 452), 'Pixel')
    $g.ResetClip()
    $img.Dispose()
}

# PNG if it fits the size limit, else JPEG at decreasing quality.
function SaveLimited($bmp, $base, $limitKB) {
    $png = "$base.png"
    $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
    if ((Get-Item $png).Length -le $limitKB * 1024) { return "$png  $([int]((Get-Item $png).Length / 1024)) KB" }
    Remove-Item $png
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    foreach ($q in 95, 92, 90, 87, 85, 80, 75) {
        $params = New-Object System.Drawing.Imaging.EncoderParameters 1
        $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$q)
        $jpg = "$base.jpg"
        $bmp.Save($jpg, $codec, $params)
        if ((Get-Item $jpg).Length -le $limitKB * 1024) { return "$jpg  $([int]((Get-Item $jpg).Length / 1024)) KB (q$q)" }
    }
    throw "$base does not fit $limitKB KB"
}

# ---- Store icon: 500 x 500, 10 px padding, solid background -----------------
$c = NewCanvas 500 500
DrawFace $c[1] 'volt' 250 250 450   # bezel outer edge r 234: 16 px padding
$c[1].Dispose()
SaveLimited $c[0] (Join-Path $Out 'store-icon-500') 300
$c[0].Dispose()

# ---- Cover image: 500 x 500, < 300 KB (web + mobile store listing) ---------
$c = NewCanvas 500 500
$g = $c[1]
DrawFace $g 'volt' 250 208 360
$wHeavy = New-Object System.Drawing.Font 'Bahnschrift SemiBold Condensed', 64, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$wThin = New-Object System.Drawing.Font 'Bahnschrift Light Condensed', 64, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$fmt = [System.Drawing.StringFormat]::GenericTypographic
$brush = New-Object System.Drawing.SolidBrush $chalk
$apW = $g.MeasureString('AP', $wHeavy, 1000, $fmt).Width
$exW = $g.MeasureString('EX', $wThin, 1000, $fmt).Width
$wx = 250 - ($apW + 3 + $exW) / 2
$g.DrawString('AP', $wHeavy, $brush, $wx, 402, $fmt)
$g.DrawString('EX', $wThin, $brush, ($wx + $apW + 3), 402, $fmt)
$g.Dispose()
SaveLimited $c[0] (Join-Path $Out 'cover-500') 300
$c[0].Dispose()

# ---- Screenshots: 500 x 500, <= 150 KB -------------------------------------
$shots = 'volt', 'aod', 'ember', 'glacier', 'signal'
for ($i = 0; $i -lt $shots.Count; $i++) {
    $c = NewCanvas 500 500
    DrawFace $c[1] $shots[$i] 250 250 440
    $c[1].Dispose()
    SaveLimited $c[0] (Join-Path $Out ("screenshot-{0}-{1}" -f ($i + 1), $shots[$i])) 150
    $c[0].Dispose()
}

# ---- Hero: 1440 x 720 ------------------------------------------------------
$c = NewCanvas 1440 720
$g = $c[1]
DrawFace $g 'volt' 1030 360 560

$heavy = New-Object System.Drawing.Font 'Bahnschrift SemiBold Condensed', 150, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$thin = New-Object System.Drawing.Font 'Bahnschrift Light Condensed', 150, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$small = New-Object System.Drawing.Font 'Bahnschrift SemiLight', 30, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$fmt = [System.Drawing.StringFormat]::GenericTypographic
$chalkBrush = New-Object System.Drawing.SolidBrush $chalk
$dimBrush = New-Object System.Drawing.SolidBrush $dim

# "AP" heavy + "EX" thin: weight, not colour, separates them (as hours / minutes)
$x = 120
$y = 200
$g.DrawString('AP', $heavy, $chalkBrush, $x, $y, $fmt)
$apWidth = $g.MeasureString('AP', $heavy, 1000, $fmt).Width
$g.DrawString('EX', $thin, $chalkBrush, ($x + $apWidth + 6), $y, $fmt)
$g.DrawString('Weight, not colour.', $small, $dimBrush, ($x + 4), ($y + 178), $fmt)

# Accent swatches: Volt, Ember, Glacier, Signal, Ghost
$accents = 0xC8FF2E, 0xFF5A1F, 0x4FD1FF, 0xFF3D7F, 0xF4F4EF
for ($i = 0; $i -lt $accents.Count; $i++) {
    $v = $accents[$i]
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(($v -shr 16) -band 0xFF, ($v -shr 8) -band 0xFF, $v -band 0xFF))
    $g.FillEllipse($brush, [single]($x + 6 + $i * 40), [single]($y + 248), 22, 22)
    $brush.Dispose()
}
$g.Dispose()
SaveLimited $c[0] (Join-Path $Out 'hero-1440x720') 1024
$c[0].Dispose()
