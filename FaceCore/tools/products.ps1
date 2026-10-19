# The watches every face ships to: all round Connect IQ watches with API 5.0+, the same 66
# products as ApexFace (rectangular Venu Sq / X1 and the semi-octagon Instinct screens are out).
# Dot-source it: . FaceCore\tools\products.ps1
#
#   $Products            product ids
#   $Screens             screen width -> 'mip' / 'amoled' (one font set per width)
#   $DeviceMatrix        one watch per screen size, screen type, API version and editor
#                        support: what run-device-tests.ps1 and capture-screens.ps1 run on
#   ScreenOf <id>        @{ Width; Type; Api } from the installed device definition

$Products = @(
    'approachs50', 'approachs7042mm', 'approachs7047mm', 'd2airx10', 'd2mach1', 'd2mach2', 'd2mach2pro',
    'descentg2', 'descentmk343mm', 'descentmk351mm', 'enduro3', 'epix2', 'epix2pro42mm', 'epix2pro47mm',
    'epix2pro51mm', 'fenix7', 'fenix7pro', 'fenix7pronowifi', 'fenix7s', 'fenix7spro', 'fenix7x',
    'fenix7xpro', 'fenix7xpronowifi', 'fenix843mm', 'fenix847mm', 'fenix8pro47mm', 'fenix8solar47mm',
    'fenix8solar51mm', 'fenix943mm', 'fenix947mm', 'fenix9pro43mm', 'fenix9pro47mm', 'fenix9pro51mm',
    'fenix9prosolar47mm', 'fenix9prosolar51mm', 'fenixe', 'fr165', 'fr165m', 'fr170', 'fr170m', 'fr255',
    'fr255m', 'fr255s', 'fr255sm', 'fr265', 'fr265s', 'fr57042mm', 'fr57047mm', 'fr70', 'fr955', 'fr965',
    'fr970', 'instinct3amoled45mm', 'instinct3amoled50mm', 'instinctcrossoveramoled', 'marq2',
    'marq2aviator', 'venu2', 'venu2plus', 'venu2s', 'venu3', 'venu3s', 'venu441mm', 'venu445mm',
    'vivoactive5', 'vivoactive6'
)

$Screens = [ordered]@{
    '218' = 'mip'; '240' = 'mip'; '260' = 'mip'; '280' = 'mip'
    '360' = 'amoled'; '390' = 'amoled'; '416' = 'amoled'; '454' = 'amoled'; '466' = 'amoled'
}

# id = what it stands for (ApexFace's device-test matrix)
$DeviceMatrix = [ordered]@{
    'fr255s'          = '218 MIP, API 5.2'
    'fenix7s'         = '240 MIP, API 5.2'
    'fenix7'          = '260 MIP, API 5.2'
    'fenix8solar47mm' = '260 MIP, API 6.0'
    'fenix7x'         = '280 MIP, API 5.2'
    'enduro3'         = '280 MIP, API 6.0'
    'venu2s'          = '360 AMOLED, API 5.0'
    'approachs50'     = '390 AMOLED, API 5.1'
    'fr165'           = '390 AMOLED, API 5.2'
    'vivoactive6'     = '390 AMOLED, API 6.0'
    'venu2'           = '416 AMOLED, API 5.0'
    'fr265'           = '416 AMOLED, API 5.2'
    'fenix843mm'      = '416 AMOLED, API 6.0'
    'fr965'           = '454 AMOLED, API 5.2'
    'fr970'           = '454 AMOLED, API 6.0'
    'fenix9pro51mm'   = '466 AMOLED, API 6.0'
}

# One watch per screen size (screenshots of every layout)
$ScreenDevices = [ordered]@{
    '218' = 'fr255s'; '240' = 'fenix7s'; '260' = 'fenix7'; '280' = 'enduro3'
    '360' = 'venu2s'; '390' = 'fr165'; '416' = 'fr265'; '454' = 'fr970'; '466' = 'fenix9pro51mm'
}

$DeviceDir = Join-Path $env:APPDATA 'Garmin\ConnectIQ\Devices'
$Sdk = (Get-ChildItem (Join-Path $env:APPDATA 'Garmin\ConnectIQ\Sdks') -Directory | Sort-Object Name | Select-Object -Last 1).FullName
$DevKey = 'C:\Users\dariu\developer_key'

function ScreenOf([string]$id) {
    $j = Get-Content (Join-Path $DeviceDir "$id\compiler.json") -Raw | ConvertFrom-Json
    $api = ($j.partNumbers | ForEach-Object { [version]$_.connectIQVersion } | Sort-Object -Descending | Select-Object -First 1)
    @{ Width = [int]$j.resolution.width; Type = $j.displayType; Api = $api; Family = $j.deviceFamily }
}
