# Store images for Tach Cluster (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (Sat 11 Oct 10:08:42, the mockup's readings) with these settings.
$Shots = [ordered]@{
    'orange'  = @{}
    'aod'     = @{ Aod = $true }
    'yellow'  = @{ Props = 'AccentColor=0xFFD400'; Hour = 14; Min = 35; Data = 'hrOverride=96' }
    'coolant' = @{ Props = 'AccentColor=0x3AD0FF'; Hour = 6; Min = 50; Data = 'hrOverride=54' }
    'redline' = @{ Props = 'AccentColor=0xE83A3A'; Hour = 23; Min = 15; Data = 'hrOverride=148' }
    'mip'     = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(@('TACH', 'BarlowCondensed-ExtraBold.ttf'), @('CLUSTER', 'BarlowCondensed-Light.ttf'))
    Tagline   = 'The hour, at the redline.'
    Swatches  = @(0xFF6A13, 0xFFD400, 0x3AD0FF, 0xE83A3A)
    Hero      = 'orange'
    Shots     = @('orange', 'aod', 'yellow', 'coolant', 'redline', 'mip')
    Trio      = @('yellow', 'coolant', 'orange')
    Quad      = @('orange', 'yellow', 'coolant', 'redline')
    Large     = 'redline'
    LargeGlow = 0xE83A3A
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xFF6A13
    Dark      = $true
    Night     = @(0x2B2D30, 0x121314)
    Muted     = 0x8D939A
}
