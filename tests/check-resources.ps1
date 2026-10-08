# Consistency checks for the resource XML (settings, defaults, watch face editor,
# strings, manifest) against the tables in CLAUDE.md. The Monkey C unit tests
# (source/*Test.mc) cover the code; this covers what they cannot read.
#
#   powershell -ExecutionPolicy Bypass -File tests\check-resources.ps1
#
# Exit code 0 = all checks passed.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script:failures = 0
$script:checks = 0

function Check([bool]$ok, [string]$what) {
    $script:checks++
    if ($ok) {
        Write-Host "PASS  $what"
    } else {
        Write-Host "FAIL  $what" -ForegroundColor Red
        $script:failures++
    }
}

function Load([string]$path) {
    [xml](Get-Content -Raw -Encoding UTF8 (Join-Path $root $path))
}

function Num([string]$text) { [int]($text.Trim()) }

# Data types of an editor slot (attribute-less <type> nodes read as strings, so use XmlElements)
function SlotTypes($slot) { @($slot.SelectNodes("type") | ForEach-Object { $_.InnerText.Trim() }) }

function SameSet($a, $b) {
    $x = @($a | Sort-Object -Unique)
    $y = @($b | Sort-Object -Unique)
    ($x.Count -eq $y.Count) -and -not (Compare-Object $x $y)
}

$properties = Load 'resources/settings/properties.xml'
$settings = Load 'resources/settings/settings.xml'
$strings = Load 'resources/strings/strings.xml'
$config = Load 'resources/configs/watchface.xml'
$manifest = Load 'manifest.xml'

# ---- Property defaults (CLAUDE.md, Settings) ------------------------------

$expectedDefaults = [ordered]@{
    Field1 = 0            # HR
    Field2 = 1            # STEPS
    Field3 = 10           # SUNSET
    Arc = 0               # BODY BATT
    AccentColor = 0xC8FF2E  # Volt
    NumeralColor = 0xF4F4EF # Chalk
    InkColor = 0xF4F4EF
    DimColor = 0xB0B0AA
    NightMode = 0         # Off
}
$props = @{}
foreach ($p in $properties.properties.property) {
    $props[$p.id] = Num $p.InnerText
}
foreach ($key in $expectedDefaults.Keys) {
    Check ($props.ContainsKey($key) -and $props[$key] -eq $expectedDefaults[$key]) "property $key defaults to $('0x{0:X}' -f $expectedDefaults[$key])"
}
foreach ($p in $properties.properties.property) {
    Check ($p.type -eq 'number') "property $($p.id) is a number"
}

# ---- Settings lists -------------------------------------------------------

$lists = @{}
foreach ($s in $settings.settings.setting) {
    $key = $s.propertyKey -replace '^@Properties\.', ''
    $lists[$key] = @($s.settingConfig.listEntry | ForEach-Object { Num $_.value })
}
foreach ($key in $props.Keys) {
    Check ($lists.ContainsKey($key)) "property $key has a setting"
    if ($lists.ContainsKey($key)) {
        Check ($lists[$key] -contains $props[$key]) "default of $key is one of its list entries"
        Check ($lists[$key].Count -eq ($lists[$key] | Sort-Object -Unique).Count) "$key list has no duplicate values"
    }
}

$fieldIds = @(0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16)   # 7 READY hidden
foreach ($key in 'Field1', 'Field2', 'Field3') {
    Check (SameSet $lists[$key] $fieldIds) "$key lists every field id except READY (7)"
}
Check (SameSet $lists['Arc'] @(0, 1, 2, 3, 5, 6)) "Arc lists every arc id except READINESS (4)"
Check (SameSet $lists["NightMode"] @(0, 1, 2)) "NightMode lists Off, Auto, On"

$accents = @(0xC8FF2E, 0xFF5A1F, 0x4FD1FF, 0xFF3D7F, 0xF4F4EF)  # design's five
foreach ($c in $accents) {
    Check ($lists['AccentColor'] -contains $c) ("AccentColor offers design colour 0x{0:X6}" -f $c)
}
foreach ($c in @(0xF4F4EF, 0xE9DFC9, 0xCFE3FF, -1)) {
    Check ($lists['NumeralColor'] -contains $c) ("NumeralColor offers {0}" -f $(if ($c -eq -1) { 'Accent (-1)' } else { '0x{0:X6}' -f $c }))
}
foreach ($c in $lists['AccentColor']) {
    Check ($lists['NumeralColor'] -contains $c) ("NumeralColor offers accent hue 0x{0:X6}" -f $c)
}

# ---- Strings --------------------------------------------------------------

$stringIds = @($strings.strings.string | ForEach-Object { $_.id })
$refs = @()
foreach ($file in 'resources/settings/settings.xml', 'resources/configs/watchface.xml', 'manifest.xml') {
    $text = Get-Content -Raw (Join-Path $root $file)
    $refs += [regex]::Matches($text, '@Strings\.(\w+)') | ForEach-Object { $_.Groups[1].Value }
}
foreach ($ref in ($refs | Sort-Object -Unique)) {
    Check ($stringIds -contains $ref) "string $ref exists"
}
Check ($stringIds.Count -eq ($stringIds | Sort-Object -Unique).Count) "string ids are unique"

# ---- Watch face editor (resources/configs/watchface.xml) ------------------

$wf = $config.resources.'watchface-config'
$slots = @{}
foreach ($c in $wf.data.complication) {
    $slots[[int]$c.id] = $c
}
Check (SameSet $slots.Keys @(1, 2, 3, 4)) "editor declares slots 1-3 (fields) and 4 (arc)"
Check ($config.SelectNodes("//*[@allowAny]").Count -eq 0) "no slot uses allowAny"

$slotDefaults = @{
    1 = 'COMPLICATION_TYPE_HEART_RATE'
    2 = 'COMPLICATION_TYPE_STEPS'
    3 = 'COMPLICATION_TYPE_SUNSET'
    4 = 'COMPLICATION_TYPE_BODY_BATTERY'
}
foreach ($id in 1..4) {
    $types = @($slots[$id].SelectNodes("type"))
    $defaults = @($types | Where-Object { $_.default -eq 'true' })
    Check ($defaults.Count -eq 1) "slot $id has exactly one default type"
    if ($defaults.Count -eq 1) {
        Check ($defaults[0].InnerText.Trim() -eq "Complications.$($slotDefaults[$id])") "slot $id defaults to $($slotDefaults[$id])"
    }
    $names = @($types | ForEach-Object { $_.InnerText.Trim() })
    Check ($names.Count -eq ($names | Sort-Object -Unique).Count) "slot $id lists no type twice"
}
$fieldSlotTypes = SlotTypes $slots[1]
foreach ($id in 2, 3) {
    Check (SameSet (SlotTypes $slots[$id]) $fieldSlotTypes) "slot $id offers the same types as slot 1"
}
# ApexMetrics.arcForComplication must know every arc slot type.
$arcTypes = @('BODY_BATTERY', 'STEPS', 'BATTERY', 'STRESS', 'INTENSITY_MINUTES') | ForEach-Object { "Complications.COMPLICATION_TYPE_$_" }
Check (SameSet (SlotTypes $slots[4]) $arcTypes) "arc slot offers exactly the types the arc maps"

foreach ($list in 'accentColors', 'dataColors') {
    $colors = @($wf.$list.color)
    $defaults = @($colors | Where-Object { $_.default -eq 'true' })
    Check ($defaults.Count -eq 1) "$list has exactly one default"
}
$editorAccents = @($wf.accentColors.color | ForEach-Object { Num $_.InnerText })
$editorData = @($wf.dataColors.color | ForEach-Object { Num $_.InnerText })
Check ((Num (@($wf.accentColors.color | Where-Object { $_.default -eq 'true' })[0].InnerText)) -eq 0xC8FF2E) "editor accent defaults to Volt"
Check ((Num (@($wf.dataColors.color | Where-Object { $_.default -eq 'true' })[0].InnerText)) -eq 0xF4F4EF) "editor data colour defaults to Chalk"
Check (SameSet $editorAccents $lists['AccentColor']) "editor and phone accent lists match"
Check (SameSet $editorData @($lists['NumeralColor'] | Where-Object { $_ -ne -1 })) "editor data colours match the phone numeral list (minus Accent)"

# ---- Manifest -------------------------------------------------------------

$app = $manifest.manifest.application
Check ($app.type -eq 'watchface') "manifest app type is watchface"
Check (@($app.products.product | ForEach-Object { $_.id }) -contains 'fr970') "manifest targets fr970"
$permissions = @($app.permissions.'uses-permission' | ForEach-Object { $_.id })
foreach ($perm in "SensorHistory", "ComplicationSubscriber", "UserProfile") {
    Check ($permissions -contains $perm) "manifest requests $perm"
}
Check ([version]$app.minApiLevel -ge [version]'5.0.0') "minApiLevel is 5.0+ (the editor itself is used only where the watch has it)"

# Products: modern round watches only (the layout is designed for a round screen)
$deviceDir = Join-Path $env:APPDATA 'Garmin\ConnectIQ\Devices'
$products = @($app.products.product | ForEach-Object { $_.id })
if (Test-Path $deviceDir) {
    foreach ($id in $products) {
        $compiler = Join-Path $deviceDir "$id\compiler.json"
        if (-not (Test-Path $compiler)) {
            Check $false "product $id has an installed device definition"
            continue
        }
        $j = Get-Content $compiler -Raw | ConvertFrom-Json
        Check ($j.deviceFamily -like 'round-*') "product $id has a round screen"
    }
}

# ---- Summary --------------------------------------------------------------

Write-Host ""
if ($script:failures -eq 0) {
    Write-Host "PASSED ($($script:checks) checks)"
    exit 0
}
Write-Host "FAILED ($script:failures of $($script:checks) checks)" -ForegroundColor Red
exit 1
