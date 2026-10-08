# crop.ps1 -In raw\x.png -Out face\x.png : cuts the 454 px display out of a simulator window
# capture (located by the 12 and 9 o'clock major ticks) and masks it to the round screen.
param([string]$In, [string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::FromFile($In)

function Bright($x, $y) { $c = $src.GetPixel($x, $y); [Math]::Max($c.R, [Math]::Max($c.G, $c.B)) }

# Expected near (162, 242); refine: the 12 o'clock tick starts at display y 213 px above centre (y = 14..2),
# the 9 o'clock tick at display x = 2..14. Search for the first row/column that lights up.
$best = $null
foreach ($ox in 150..175) {
    foreach ($oy in 230..255) {
        $top = Bright ($ox + 227) ($oy + 3)
        $above = Bright ($ox + 227) ($oy - 3)
        $left = Bright ($ox + 3) ($oy + 227)
        $outside = Bright ($ox - 3) ($oy + 227)
        $score = $top + $left - $above - $outside
        if ($best -eq $null -or $score -gt $best[2]) { $best = @($ox, $oy, $score) }
    }
}
$ox = 162; $oy = 243   # fixed simulator layout (verified on the active frames)
"display origin in capture: ($ox, $oy) score $($best[2])"

$face = New-Object System.Drawing.Bitmap 454, 454, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($face)
$g.SmoothingMode = 'AntiAlias'
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(0, 0, 454, 454)
$g.SetClip($path)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, 454, 454), (New-Object System.Drawing.Rectangle $ox, $oy, 454, 454), 'Pixel')
$g.Dispose()
$face.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$face.Dispose()
$src.Dispose()
