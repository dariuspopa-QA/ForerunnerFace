# Runs the unit tests on one watch per screen type, Connect IQ API version and editor
# config, so every supported product is covered (the per-watch tests in
# source/ApexDeviceTest.mc check the layout on the screen they run on).
#
#   powershell -ExecutionPolicy Bypass -File tools\run-device-tests.ps1 [-Devices fr970,fenix7]
#
# Needs the Connect IQ simulator running. Exit code 0 = every device passed.
param([string]$Devices = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sdk = Get-ChildItem "$env:APPDATA\Garmin\ConnectIQ\Sdks" -Directory | Sort-Object Name | Select-Object -Last 1
$key = 'C:\Users\dariu\developer_key'

# id: screen, type, API, editor config
$matrix = [ordered]@{
    'fr255s'          = '218 MIP, API 5.2, editor-basic'
    'fenix7s'         = '240 MIP, API 5.2, editor-basic'
    'fenix7'          = '260 MIP, API 5.2, editor-basic'
    'fenix8solar47mm' = '260 MIP, API 6.0, editor-full'
    'fenix7x'         = '280 MIP, API 5.2, editor-basic'
    'enduro3'         = '280 MIP, API 6.0, editor-full'
    'venu2s'          = '360 AMOLED, API 5.0, editor-basic'
    'approachs50'     = '390 AMOLED, API 5.1, editor-basic'
    'fr165'           = '390 AMOLED, API 5.2, editor-basic'
    'vivoactive6'     = '390 AMOLED, API 6.0, editor-full'
    'venu2'           = '416 AMOLED, API 5.0, editor-basic'
    'fr265'           = '416 AMOLED, API 5.2, editor-basic'
    'fenix843mm'      = '416 AMOLED, API 6.0, editor-full'
    'fr965'           = '454 AMOLED, API 5.2, editor-basic'
    'fr970'           = '454 AMOLED, API 6.0, editor-full'
    'fenix9pro51mm'   = '466 AMOLED, API 6.0, editor-full'
}
$ids = if ($Devices) { $Devices.Split(',') | ForEach-Object { $_.Trim() } } else { @($matrix.Keys) }

$outDir = Join-Path $root 'bin\device-tests'
New-Item -ItemType Directory -Force $outDir | Out-Null
$results = @()
foreach ($id in $ids) {
    $prg = Join-Path $outDir "$id.prg"
    $build = & "$($sdk.FullName)\bin\monkeyc.bat" -f (Join-Path $root 'monkey.jungle') -d $id -o $prg -y $key --unit-test -l 3 2>&1
    if (-not ($build -match 'BUILD SUCCESSFUL')) {
        $results += [pscustomobject]@{ Device = $id; Config = $matrix[$id]; Result = 'BUILD FAILED'; Failing = (($build | Select-Object -Last 3) -join ' ') }
        continue
    }
    $run = & "$($sdk.FullName)\bin\monkeydo.bat" $prg $id /t 2>&1 | ForEach-Object { "$_" }
    $summary = $run | Where-Object { $_ -match '^(PASSED|FAILED) \(' } | Select-Object -Last 1
    $count = $run | Where-Object { $_ -match '^Ran \d+ tests' } | Select-Object -Last 1
    $failing = @($run | Where-Object { $_ -match '^(\w+)\s+(ERROR|FAIL)$' } | ForEach-Object { ($_ -split '\s+')[0] }) -join ', '
    $results += [pscustomobject]@{ Device = $id; Config = $matrix[$id]; Result = "$count $summary"; Failing = $failing }
    "{0,-16} {1,-34} {2}" -f $id, $matrix[$id], "$count $summary"
}

""
$results | Format-Table -AutoSize -Wrap | Out-String -Width 200
$bad = @($results | Where-Object { $_.Result -cnotmatch 'PASSED \(' })   # case-sensitive: "FAILED (passed=..." contains "passed"
if ($bad.Count -eq 0) {
    "ALL $($results.Count) DEVICES PASSED"
    exit 0
}
"$($bad.Count) of $($results.Count) devices failed"
exit 1
