# Writes FaceCore's product list (products.ps1) into a face's manifest.xml, keeping the
# rest of the generated file as it is.
#
#   powershell -ExecutionPolicy Bypass -File FaceCore\tools\set-products.ps1 -Face Meridian
param([Parameter(Mandatory)][string]$Face)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'products.ps1')
$root = Resolve-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) $Face)
$path = Join-Path $root 'manifest.xml'
$text = [IO.File]::ReadAllText($path)
$m = [regex]::Match($text, '(?s)(?<indent>[ \t]*)<iq:products>.*?</iq:products>')
if (-not $m.Success) { throw "no <iq:products> in $path" }
$indent = $m.Groups['indent'].Value
$lines = @("$indent<iq:products>") + ($Products | ForEach-Object { "$indent    <iq:product id=`"$_`"/>" }) + @("$indent</iq:products>")
$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$text = $text.Substring(0, $m.Index) + ($lines -join $nl) + $text.Substring($m.Index + $m.Length)
[IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
"$Face`: $($Products.Count) products"
