# Generates the Connect IQ bitmap fonts (BMFont text .fnt + .png) for every screen size
# the products use, into resources-round-<W>x<W>/fonts/. Sources: tools/fonts/*.ttf
# (Barlow Condensed, DM Mono; SIL Open Font License, see tools/fonts/OFL-*.txt).
#
#   powershell -ExecutionPolicy Bypass -File tools\make-fonts.ps1
#
# Sizes are the design sizes (CLAUDE.md, Fonts) times width / 454, with minimums so the
# small text stays legible on 218-280 px screens. Each font's line box is cropped to the
# glyphs' ink from cap top to the lowest descender, so TEXT_JUSTIFY_VCENTER centres the digits.
# MIP screens (64 colours) get 1-bit hinted glyphs below 20 px, where anti-aliasing blurs.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $PSScriptRoot 'fonts'

# width -> screen type (from the products' device definitions)
$screens = [ordered]@{ '218' = 'mip'; '240' = 'mip'; '260' = 'mip'; '280' = 'mip'; '360' = 'amoled'; '390' = 'amoled'; '416' = 'amoled'; '454' = 'amoled'; '466' = 'amoled' }

$digits = '0123456789'
$upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
$lower = 'abcdefghijklmnopqrstuvwxyz'
# id, file, ttf, design px, minimum px, glyphs
$fonts = @(
    # the optional colon (TimeColon setting) is drawn in the minutes' thin weight
    @('TimeHeavy', 'time_heavy', 'BarlowCondensed-ExtraBold.ttf', 176, 0, $digits),
    @('TimeThin', 'time_thin', 'BarlowCondensed-ExtraLight.ttf', 176, 0, ($digits + ':')),
    @('TimeAod', 'time_aod', 'BarlowCondensed-Light.ttf', 176, 0, $digits),
    # values: metric formats plus letters for system data fields (e.g. "GOOD", "ms")
    @('Value', 'value', 'BarlowCondensed-SemiBold.ttf', 34, 16, ($digits + ',.:%-/+ ' + [char]0xB0 + $upper + $lower)),
    @('ArcValue', 'arc_value', 'BarlowCondensed-SemiBold.ttf', 32, 15, ($digits + '%-')),
    @('Mono22', 'mono22', 'DMMono-Regular.ttf', 26, 12, ($upper + $digits + ' -')),
    @('Mono16', 'mono16', 'DMMono-Regular.ttf', 18, 10, ($upper + $digits + ' ./-%' + [char]0xB0)),
    @('Mono14', 'mono14', 'DMMono-Regular.ttf', 16, 10, ($upper + ' '))
)

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

function MakeFont([string]$outDir, [string]$file, [string]$ttf, [int]$px, [string]$glyphs, [bool]$crisp) {
    $family = FamilyFor $ttf
    $style = StyleFor $family
    $font = New-Object System.Drawing.Font $family, $px, $style, ([System.Drawing.GraphicsUnit]::Pixel)
    $ascent = $px * $family.GetCellAscent($style) / $family.GetEmHeight($style)
    $descent = $px * $family.GetCellDescent($style) / $family.GetEmHeight($style)
    $fmt = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    $fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    $hint = if ($crisp) { 'SingleBitPerPixelGridFit' } else { 'AntiAlias' }

    $pad = [int][Math]::Ceiling($px * 0.3) + 2
    $cellW = [int][Math]::Ceiling($px * 1.6) + 2 * $pad
    $cellH = [int][Math]::Ceiling($ascent + $descent) + 2 * $pad
    $glyphList = @()
    foreach ($ch in $glyphs.ToCharArray()) {
        $cell = New-Object System.Drawing.Bitmap $cellW, $cellH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($cell)
        $g.TextRenderingHint = $hint
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawString([string]$ch, $font, [System.Drawing.Brushes]::White, [single]$pad, [single]$pad, $fmt)
        $adv = $g.MeasureString([string]$ch, $font, (New-Object System.Drawing.PointF 0, 0), $fmt).Width
        $g.Dispose()
        # ink bounding box
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

    # Line box: from the highest capital/digit top to the baseline
    $baseline = $pad + $ascent
    $capTop = ($glyphList | Where-Object { $_.maxX -ge 0 -and ([string]$_.ch -match '[A-Z0-9]') } | Measure-Object -Property minY -Minimum).Minimum
    if ($capTop -eq $null) { $capTop = ($glyphList | Where-Object { $_.maxX -ge 0 } | Measure-Object -Property minY -Minimum).Minimum }
    # ...extended down to the lowest glyph: Connect IQ clips ink below the line box
    # (the comma in "8,214"). Digit-only fonts have no descenders, so they stay cap-high.
    $bottom = ($glyphList | Where-Object { $_.maxX -ge 0 } | Measure-Object -Property maxY -Maximum).Maximum + 1
    if ($bottom -lt $baseline) { $bottom = $baseline }
    $lineHeight = [int][Math]::Round($bottom - $capTop)
    $baseOffset = [int][Math]::Round($baseline - $capTop)

    # Pack into an atlas
    $atlasW = 512
    while ($true) {
        $x = 0; $y = 0; $rowH = 0; $ok = $true
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
            # Time fonts (digits only): the colon sits at text height in the typeface;
            # centre it on the digits instead.
            if ([string]$gl.ch -eq ':' -and $glyphs -notmatch '[A-Za-z]') {
                $yoff = [int][Math]::Round(($baseline - $capTop - $gl.h) / 2)
            }
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
    return $lineHeight
}

foreach ($w in $screens.Keys) {
    $type = $screens[$w]
    $outDir = Join-Path $root "resources-round-${w}x${w}\fonts"
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $xml = @('<fonts>')
    $summary = @()
    foreach ($f in $fonts) {
        $px = [int][Math]::Round($f[3] * $w / 454.0)
        if ($px -lt $f[4]) { $px = $f[4] }
        $crisp = ($type -eq 'mip') -and ($px -lt 20)
        $lh = MakeFont $outDir $f[1] $f[2] $px $f[5] $crisp
        $aa = if ($crisp) { 'false' } else { 'true' }
        $xml += "    <font id=`"$($f[0])`" filename=`"$($f[1]).fnt`" antialias=`"$aa`"/>"
        $summary += "$($f[0]) ${px}px"
    }
    $xml += '</fonts>'
    [IO.File]::WriteAllLines((Join-Path $outDir 'fonts.xml'), $xml)
    "${w}x${w} ($type): " + ($summary -join ', ')
}
