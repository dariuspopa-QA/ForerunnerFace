# Builds a face's Connect IQ Store package for all its products (release build, no demo
# code): <face>\dist\<Folder>-<version>.iq, the version from the manifest.
#
#   powershell -ExecutionPolicy Bypass -File FaceCore\tools\package.ps1 -Face Meridian
#
# The export compiles every product, so it is also the full build check across all 66 watches.
param([Parameter(Mandatory)][string]$Face)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'products.ps1')
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = (Resolve-Path (Join-Path $repo $Face)).Path
$name = Split-Path -Leaf $root
$manifest = [xml](Get-Content -Raw (Join-Path $root 'manifest.xml'))
$version = $manifest.manifest.application.version
if (-not $version) { throw "$name has no version in its manifest" }
$count = @($manifest.manifest.application.products.product).Count
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$out = Join-Path $dist "$name-$version.iq"
$build = & "$Sdk\bin\monkeyc.bat" -e -f (Join-Path $root 'monkey.jungle') -o $out -y $DevKey -r 2>&1
if (-not ($build -match 'BUILD SUCCESSFUL')) {
    $build | Select-String 'ERROR' | Select-Object -First 20 | Out-Host
    throw "$name $version : package build failed"
}
$warnings = @($build | Select-String 'WARNING' | Where-Object { $_ -notmatch 'launcher icon|scaled' })
"$name $version : $out ($count products, $([int]((Get-Item $out).Length / 1024)) KB$(if ($warnings.Count) { ", $($warnings.Count) warnings" }))"
