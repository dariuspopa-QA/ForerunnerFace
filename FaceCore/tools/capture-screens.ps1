# Captures a face on one watch per screen size (products.ps1 $ScreenDevices: 218-280 px MIP,
# 360-466 px AMOLED) from its demo build, into <face>\store\faces\devices\<id>.png, and composes
# the store's per-screen screenshots and overview (compose-devices.ps1 -> <face>\store\watches).
#
#   powershell -ExecutionPolicy Bypass -File FaceCore\tools\capture-screens.ps1 -Face Meridian
#       [-Devices fr255s,fr970] [-Props ...] [-Demo ...] [-Aod] [-NoCompose]
#
# Needs the simulator running and visible. Extra arguments pass on to shot.ps1.
param([Parameter(Mandatory)][string]$Face, [string]$Devices = '', [string]$Props = '', [string]$Demo = '',
    [switch]$Aod, [switch]$NoCompose, [string]$Dir = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'products.ps1')
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = Join-Path $repo $Face
if (-not $Dir) { $Dir = Join-Path $root 'store\faces\devices' }
New-Item -ItemType Directory -Force $Dir | Out-Null
$ids = if ($Devices) { $Devices.Split(',') | ForEach-Object { $_.Trim() } } else { @($ScreenDevices.Values) }
foreach ($id in $ids) {
    $args2 = @('-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'shot.ps1'), '-Face', $Face, '-Device', $id,
        '-Out', (Join-Path $Dir "$id.png"))
    if ($Props) { $args2 += @('-Props', $Props) }
    if ($Demo) { $args2 += @('-Demo', $Demo) }
    if ($Aod) { $args2 += '-Aod' }
    & powershell @args2
}
if (-not $NoCompose -and -not $Devices) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'compose-devices.ps1') -Faces $Dir -Out (Join-Path $root 'store')
}
