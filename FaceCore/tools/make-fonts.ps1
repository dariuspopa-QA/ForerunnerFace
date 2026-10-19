# Generates a face's Connect IQ bitmap fonts (BMFont text .fnt + .png) for every screen
# size the products use (FaceCore/tools/products.ps1), into <face>/resources-round-<W>x<W>/fonts/.
# The fonts and their design sizes are listed in <face>/tools/font-table.ps1; sources are
# <face>/tools/fonts/*.ttf (SIL Open Font License, static instances from Google Fonts).
#
#   powershell -ExecutionPolicy Bypass -File FaceCore\tools\make-fonts.ps1 -Face <face folder>
#   (each face's tools\make-fonts.ps1 calls this for its own folder)
#
# Sizes are the 454 px design sizes times width / 454, with each font's minimum so small
# text stays legible on small screens. Each font's line box is cropped to the glyphs' ink
# from cap top to the lowest descender, so TEXT_JUSTIFY_VCENTER centres capitals and digits.
# MIP screens (64 colours) get 1-bit hinted glyphs below 20 px, where anti-aliasing blurs
# (as ApexFace). A font-table row may add a 7th entry 'italic': the glyphs are slanted
# (sheared about the baseline), for faces whose design sets that text in italics.
# (Adapted from ApexFace/tools/make-fonts.ps1.)
param([Parameter(Mandatory)][string]$Face)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'products.ps1')
$root = (Resolve-Path $Face).Path
$src = Join-Path $root 'tools\fonts'

# width -> 'mip' / 'amoled'
$screens = $Screens

$digits = '0123456789'
$upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
$lower = 'abcdefghijklmnopqrstuvwxyz'
$ascii = -join ((32..126) | ForEach-Object { [char]$_ })
$degree = [string][char]0xB0
$middot = [string][char]0xB7

# $fonts: @(id, file, ttf, design px, minimum px, glyphs [, 'italic'])
. (Join-Path $root 'tools\font-table.ps1')

$collections = @{}
function FamilyFor([string]$ttf) {
    if (-not $collections.ContainsKey($ttf)) {
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        $pfc.AddFontFile((Join-Path $src $ttf))
        $collections[$ttf] = $pfc
    }
    $collections[$ttf].Families[0]
}

function StyleFor($family) {
    foreach ($s in 'Regular', 'Bold', 'Italic', 'BoldItalic') {
        if ($family.IsStyleAvailable([System.Drawing.FontStyle]$s)) { return [System.Drawing.FontStyle]$s }
    }
    throw "no style for $($family.Name)"
}

function MakeFont([string]$outDir, [string]$file, [string]$ttf, [int]$px, [string]$glyphs, [bool]$crisp, [bool]$italic) {
    $family = FamilyFor $ttf
    $style = StyleFor $family
    $font = New-Object System.Drawing.Font $family, $px, $style, ([System.Drawing.GraphicsUnit]::Pixel)
    $ascent = $px * $family.GetCellAscent($style) / $family.GetEmHeight($style)
    $descent = $px * $family.GetCellDescent($style) / $family.GetEmHeight($style)
    $fmt = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    $fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

    $pad = [int][Math]::Ceiling($px * 0.3) + 2
    $cellW = [int][Math]::Ceiling($px * 1.6) + 2 * $pad
    $cellH = [int][Math]::Ceiling($ascent + $descent) + 2 * $pad
    $glyphList = @()
    foreach ($ch in $glyphs.ToCharArray()) {
        $cell = New-Object System.Drawing.Bitmap $cellW, $cellH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($cell)
        $g.TextRenderingHint = if ($crisp) { 'SingleBitPerPixelGridFit' } else { 'AntiAlias' }
        $g.Clear([System.Drawing.Color]::Transparent)
        $adv = $g.MeasureString([string]$ch, $font, (New-Object System.Drawing.PointF 0, 0), $fmt).Width
        if ($italic) {
            # slant 12 degrees about the baseline: x' = x + k (baseline - y)
            $k = [single]0.21
            $g.Transform = New-Object System.Drawing.Drawing2D.Matrix 1, 0, (-$k), 1, ([single]($k * ($pad + $ascent))), 0
        }
        $g.DrawString([string]$ch, $font, [System.Drawing.Brushes]::White, [single]$pad, [single]$pad, $fmt)
        $g.Dispose()
        $minX = $cellW; $minY = $cellH; $maxX = -1; $maxY = -1
        $data = $cell.LockBits((New-Object System.Drawing.Rectangle 0, 0, $cellW, $cellH), 'ReadOnly', $cell.PixelFormat)
        $bytes = New-Object byte[] ($data.Stride * $cellH)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        $cell.UnlockBits($data)
        for ($y = 0; $y -lt $cellH; $y++) {
            $row = $y * $data.Stride
            for ($x = 0; $x -lt $cellW; $x++) {
                if ($bytes[$row + $x * 4 + 3] -gt 8) {
                    if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }
        $glyphList += [pscustomobject]@{ ch = $ch; cell = $cell; minX = $minX; minY = $minY; maxX = $maxX; maxY = $maxY; adv = [int][Math]::Round($adv) }
    }

    # Line box: from the highest capital/digit top down to the lowest ink
    $baseline = $pad + $ascent
    $capTop = ($glyphList | Where-Object { $_.maxX -ge 0 -and ([string]$_.ch -cmatch '[A-Z0-9]') } | Measure-Object -Property minY -Minimum).Minimum
    if ($capTop -eq $null) { $capTop = ($glyphList | Where-Object { $_.maxX -ge 0 } | Measure-Object -Property minY -Minimum).Minimum }
    $bottom = ($glyphList | Where-Object { $_.maxX -ge 0 } | Measure-Object -Property maxY -Maximum).Maximum + 1
    if ($bottom -lt $baseline) { $bottom = $baseline }
    $lineHeight = [int][Math]::Round($bottom - $capTop)
    $baseOffset = [int][Math]::Round($baseline - $capTop)

    $atlasW = 512
    while ($true) {
        $x = 0; $y = 0; $rowH = 0
        foreach ($gl in $glyphList) {
            $w = if ($gl.maxX -ge 0) { $gl.maxX - $gl.minX + 1 } else { 1 }
            $h = if ($gl.maxX -ge 0) { $gl.maxY - $gl.minY + 1 } else { 1 }
            if ($x + $w -gt $atlasW) { $x = 0; $y += $rowH + 1; $rowH = 0 }
            $gl | Add-Member -Force NoteProperty ax $x
            $gl | Add-Member -Force NoteProperty ay $y
            $gl | Add-Member -Force NoteProperty w $w
            $gl | Add-Member -Force NoteProperty h $h
            $x += $w + 1
            if ($h -gt $rowH) { $rowH = $h }
        }
        $atlasH = $y + $rowH
        if ($atlasH -le $atlasW * 2 -or $atlasW -ge 2048) { break }
        $atlasW *= 2
    }
    $atlas = New-Object System.Drawing.Bitmap $atlasW, ([Math]::Max(1, $atlasH)), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $ga = [System.Drawing.Graphics]::FromImage($atlas)
    $ga.Clear([System.Drawing.Color]::Transparent)
    $lines = @()
    foreach ($gl in $glyphList) {
        if ($gl.maxX -ge 0) {
            $ga.DrawImage($gl.cell, (New-Object System.Drawing.Rectangle $gl.ax, $gl.ay, $gl.w, $gl.h),
                (New-Object System.Drawing.Rectangle $gl.minX, $gl.minY, $gl.w, $gl.h), 'Pixel')
            $xoff = $gl.minX - $pad
            $yoff = [int][Math]::Round($gl.minY - $capTop)
        } else {
            $xoff = 0; $yoff = 0
        }
        $lines += "char id=$([int]$gl.ch) x=$($gl.ax) y=$($gl.ay) width=$($gl.w) height=$($gl.h) xoffset=$xoff yoffset=$yoff xadvance=$($gl.adv) page=0 chnl=15"
        $gl.cell.Dispose()
    }
    $ga.Dispose()
    $atlas.Save((Join-Path $outDir "$file.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $atlas.Dispose()

    $fnt = @(
        "info face=`"$($family.Name)`" size=$px bold=0 italic=0 charset=`"`" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1",
        "common lineHeight=$lineHeight base=$baseOffset scaleW=$atlasW scaleH=$([Math]::Max(1, $atlasH)) pages=1 packed=0",
        "page id=0 file=`"$file.png`"",
        "chars count=$($glyphList.Count)"
    ) + $lines
    [IO.File]::WriteAllLines((Join-Path $outDir "$file.fnt"), $fnt)
    $font.Dispose()
}

# Smallest text on the 218-280 px MIP screens: below this the crisp glyphs stop reading
$MIP_FLOOR = 10

# Pixel size of a font-table row on a screen of width w. The table's minimum is for the
# 360 px screen; smaller screens scale it down with the layout, to MIP_FLOOR at least.
function SizeFor($f, [int]$w) {
    $px = [int][Math]::Round($f[3] * $w / 454.0)
    $min = $f[4]
    if ($w -lt 360 -and $min -gt 0) { $min = [Math]::Max($MIP_FLOOR, [int][Math]::Round($min * $w / 360.0)) }
    if ($px -lt $min) { $px = $min }
    return $px
}

foreach ($w in $screens.Keys) {
    $type = $screens[$w]
    $outDir = Join-Path $root "resources-round-${w}x${w}\fonts"
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $xml = @('<fonts>')
    $summary = @()
    foreach ($f in $fonts) {
        $px = SizeFor $f ([int]$w)
        $crisp = ($type -eq 'mip') -and ($px -lt 20)
        $italic = ($f.Count -gt 6) -and ($f[6] -eq 'italic')
        MakeFont $outDir $f[1] $f[2] $px $f[5] $crisp $italic
        $aa = if ($crisp) { 'false' } else { 'true' }
        $xml += "    <font id=`"$($f[0])`" filename=`"$($f[1]).fnt`" antialias=`"$aa`"/>"
        $summary += "$($f[0]) ${px}px"
    }
    $xml += '</fonts>'
    [IO.File]::WriteAllLines((Join-Path $outDir 'fonts.xml'), $xml)
    "${w}x${w} ($type): " + ($summary -join ', ')
}
