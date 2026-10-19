# Runs faces' unit tests (their own <Face>Test.mc, the core's tests and, for FaceCoreView
# faces, FaceCore/face/FaceDeviceTest.mc) on one watch per screen size, screen type and
# Connect IQ API version (products.ps1 $DeviceMatrix), so every product is covered.
# (Adapted from ApexFace/tools/run-device-tests.ps1.)
#
#   powershell -ExecutionPolicy Bypass -File FaceCore\tools\run-device-tests.ps1 -Face Meridian,Tide [-Devices fr970,fenix7] [-Jobs 4]
#
# Builds every face / device pair first, -Jobs at a time (the compiler is the slow part), then
# runs the tests one by one: there is only one simulator. A run that hangs for 120 s restarts
# the simulator and is tried once more. Exit code 0 = every device of every face passed.
param([Parameter(Mandatory)][string[]]$Face, [string]$Devices = '', [int]$Jobs = 4)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'products.ps1')
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$faces = @($Face | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$ids = if ($Devices) { $Devices.Split(',') | ForEach-Object { $_.Trim() } } else { @($DeviceMatrix.Keys) }

# ---- Build, in parallel ----
$todo = New-Object System.Collections.Queue
foreach ($f in $faces) {
    $root = (Resolve-Path (Join-Path $repo $f)).Path
    $outDir = Join-Path $root 'bin\device-tests'
    New-Item -ItemType Directory -Force $outDir | Out-Null
    foreach ($id in $ids) {
        # One folder per device: monkeyc puts its gen/ next to the output, and parallel
        # builds sharing one gen/ corrupt each other.
        $devDir = Join-Path $outDir $id
        New-Item -ItemType Directory -Force $devDir | Out-Null
        $prg = Join-Path $devDir "$id.prg"
        Remove-Item $prg -ErrorAction SilentlyContinue
        $todo.Enqueue([pscustomobject]@{ Face = $f; Id = $id; Prg = $prg; Root = $root; Log = Join-Path $devDir "$id.build.log" })
    }
}
$all = @($todo.ToArray())
$running = @()
while ($todo.Count -gt 0 -or $running.Count -gt 0) {
    $running = @($running | Where-Object { -not $_.HasExited })
    while ($todo.Count -gt 0 -and $running.Count -lt $Jobs) {
        $t = $todo.Dequeue()
        $running += Start-Process "$Sdk\bin\monkeyc.bat" -NoNewWindow -PassThru `
            -ArgumentList '-f', (Join-Path $t.Root 'monkey.jungle'), '-d', $t.Id, '-o', $t.Prg, '-y', $DevKey, '--unit-test' `
            -RedirectStandardOutput $t.Log -RedirectStandardError "$($t.Log).err"
    }
    Start-Sleep -Milliseconds 500
}
"built $($all.Count) test apps"

# ---- Run, one at a time ----
function Restart-Simulator {
    Get-Process simulator -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'monkeydo|com\.garmin\.monkeybrains\.monkeydo' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep 2
    Start-Process (Join-Path $Sdk 'bin\simulator.exe')
    Start-Sleep 10
}
function Invoke-Test($t) {
    $log = $t.Prg -replace '\.prg$', '.log'
    $p = Start-Process "$Sdk\bin\monkeydo.bat" -ArgumentList $t.Prg, $t.Id, '/t' -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    if (-not $p.WaitForExit(120000)) {
        try { taskkill /PID $p.Id /T /F 2>&1 | Out-Null } catch {}
        return $null
    }
    $out = @(Get-Content $log -ErrorAction SilentlyContinue) + @(Get-Content "$log.err" -ErrorAction SilentlyContinue)
    if ($out -match 'Unable to connect to simulator') { return $null }   # it died: restart, retry
    return $out
}
if (-not (Get-Process simulator -ErrorAction SilentlyContinue)) { Restart-Simulator }

$results = @()
$lastFace = ''
foreach ($t in $all) {
    if ($t.Face -ne $lastFace) { "=== $($t.Face)"; $lastFace = $t.Face }
    $cfg = $DeviceMatrix[$t.Id]
    if (-not (Test-Path $t.Prg)) {
        $why = ((Get-Content $t.Log, "$($t.Log).err" -ErrorAction SilentlyContinue | Select-Object -Last 4) -join ' ')
        $results += [pscustomobject]@{ Face = $t.Face; Device = $t.Id; Config = $cfg; Result = 'BUILD FAILED'; Failing = $why }
        "{0,-16} {1,-22} BUILD FAILED" -f $t.Id, $cfg
        continue
    }
    $run = Invoke-Test $t
    if ($null -eq $run) { Restart-Simulator; $run = Invoke-Test $t }
    if ($null -eq $run) { $run = @('TIMEOUT or no simulator, twice') }
    $summary = $run | Where-Object { $_ -match '^(PASSED|FAILED|ERROR) \(' } | Select-Object -Last 1
    $count = $run | Where-Object { $_ -match '^Ran \d+ tests' } | Select-Object -Last 1
    $failing = @($run | Where-Object { $_ -match '^(\S+)\s+(ERROR|FAIL)$' } | ForEach-Object { ($_ -split '\s+')[0] }) -join ', '
    if (-not $summary) { $summary = 'NO RESULT: ' + (($run | Select-Object -Last 3) -join ' ') }
    $results += [pscustomobject]@{ Face = $t.Face; Device = $t.Id; Config = $cfg; Result = "$count $summary"; Failing = $failing }
    "{0,-16} {1,-22} {2} {3}" -f $t.Id, $cfg, "$count $summary", $failing
}

""
foreach ($f in $faces) {
    $mine = @($results | Where-Object { $_.Face -eq $f })
    $bad = @($mine | Where-Object { $_.Result -cnotmatch 'PASSED \(' })   # case-sensitive: "FAILED (passed=..." contains "passed"
    if ($bad.Count -eq 0) { "$f`: ALL $($mine.Count) DEVICES PASSED" } else { "$f`: $($bad.Count) of $($mine.Count) devices failed" }
}
$bad = @($results | Where-Object { $_.Result -cnotmatch 'PASSED \(' })
if ($bad.Count -eq 0) { exit 0 }
""
$bad | Format-Table -AutoSize -Wrap | Out-String -Width 200
exit 1
