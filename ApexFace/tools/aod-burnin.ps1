# aod-burnin.ps1 -Frames "f0.png,f1.png,..." : checks Always-On frames (one per consecutive
# minute, round display crops) against Garmin's AMOLED rules: at most 10 % of the screen lit
# per update, and no pixel lit for more than 3 consecutive minutes. The frame list is treated
# as a cycle (the burn-in shift pattern repeats while the hour stays the same).
param([string]$Frames, [int]$Threshold = 12, [double]$MaxLit = 0.10, [int]$MaxMinutes = 3, [string]$MapOut = "")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$frameList = $Frames.Split(",") | ForEach-Object { $_.Trim() }
$masks = @()
$size = 0
foreach ($f in $frameList) {
    $bmp = [System.Drawing.Bitmap]::FromFile((Resolve-Path $f))
    $size = $bmp.Width
    $data = $bmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height), 'ReadOnly', ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb))
    $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    $mask = New-Object bool[] ($size * $size)
    $r = $size / 2.0
    $inside = 0; $lit = 0
    for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
            $dx = $x + 0.5 - $r; $dy = $y + 0.5 - $r
            if ($dx * $dx + $dy * $dy -gt ($r - 3) * ($r - 3)) { continue }   # outside the round screen (and the simulator bezel edge)
            $inside++
            $i = $y * $data.Stride + $x * 4
            $v = [Math]::Max($bytes[$i], [Math]::Max($bytes[$i + 1], $bytes[$i + 2]))
            if ($v -gt $Threshold) { $mask[$y * $size + $x] = $true; $lit++ }
        }
    }
    $bmp.Dispose()
    $share = $lit / $inside
    "{0}: {1:P2} lit {2}" -f (Split-Path $f -Leaf), $share, $(if ($share -le $MaxLit) { 'OK' } else { 'OVER LIMIT' })
    $masks += , $mask
}

# Longest cyclic run of consecutive lit frames per pixel
$n = $masks.Count
$worst = 0; $over = 0
for ($p = 0; $p -lt $size * $size; $p++) {
    $run = 0; $best = 0
    for ($k = 0; $k -lt 2 * $n; $k++) {
        if ($masks[$k % $n][$p]) { $run++; if ($run -gt $best) { $best = $run } } else { $run = 0 }
    }
    if ($best -gt $n) { $best = $n }
    if ($best -gt $worst) { $worst = $best }
    if ($best -gt $MaxMinutes) { $over++ }
}
"longest a pixel stays lit: $worst min (limit $MaxMinutes); pixels over the limit: $over"

# Optional map of the offending pixels (red) over the first frame
if ($MapOut -and $over -gt 0) {
    $map = [System.Drawing.Bitmap]::FromFile((Resolve-Path $frameList[0]))
    $out = New-Object System.Drawing.Bitmap $map
    $map.Dispose()
    for ($p = 0; $p -lt $size * $size; $p++) {
        $run = 0; $best = 0
        for ($k = 0; $k -lt 2 * $n; $k++) {
            if ($masks[$k % $n][$p]) { $run++; if ($run -gt $best) { $best = $run } } else { $run = 0 }
        }
        if ($best -gt $MaxMinutes) { $out.SetPixel($p % $size, [Math]::Floor($p / $size), [System.Drawing.Color]::Red) }
    }
    $out.Save($MapOut)
    "map saved: $MapOut"
}
