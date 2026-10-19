# Captures a face's store shots ($Shots in <face>\store\store-config.ps1) into
# <face>\store\faces\<name>.png with shot.ps1, then composes the store images
# (compose-store.ps1).
#
#   powershell -ExecutionPolicy Bypass -File FaceCore\tools\store-shots.ps1 -Face Meridian [-Only ember,aod] [-NoCompose]
#
# A shot is @{ Device; Props; Demo; Data; Hour; Min; Sec; Aod } (all optional; default
# device fr970). Needs the simulator running and visible.
param([Parameter(Mandatory)][string]$Face, [string]$Only = '', [switch]$NoCompose)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = (Resolve-Path (Join-Path $repo $Face)).Path
. (Join-Path $root 'store\store-config.ps1')
$dir = Join-Path $root 'store\faces'
New-Item -ItemType Directory -Force $dir | Out-Null
$names = if ($Only) { $Only.Split(',') | ForEach-Object { $_.Trim() } } else { @($Shots.Keys) }
foreach ($name in $names) {
    $s = $Shots[$name]
    $a = @('-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'shot.ps1'), '-Face', $Face,
        '-Device', $(if ($s.Device) { $s.Device } else { 'fr970' }), '-Out', (Join-Path $dir "$name.png"))
    foreach ($k in 'Props', 'Demo', 'Data') { if ($s[$k]) { $a += @("-$k", $s[$k]) } }
    foreach ($k in 'Hour', 'Min', 'Sec') { if ($s.ContainsKey($k)) { $a += @("-$k", [string]$s[$k]) } }
    if ($s.Aod) { $a += '-Aod' }
    & powershell @a
}
if (-not $NoCompose) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'compose-store.ps1') -Face $Face
}
