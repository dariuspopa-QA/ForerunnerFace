# Store images for Socket Set (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (Sat 11 Oct 10:08:42, the mockup's readings) with these settings.
$Shots = [ordered]@{
    'orange'  = @{}
    'aod'     = @{ Aod = $true }
    'yellow'  = @{ Props = 'AccentColor=0xFFD400'; Hour = 3; Min = 47; Sec = 15 }
    'coolant' = @{ Props = 'AccentColor=0x3AD0FF'; Hour = 7; Min = 21; Sec = 5 }
    'redline' = @{ Props = 'AccentColor=0xE83A3A'; Hour = 11; Min = 55; Sec = 30 }
    'mip'     = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(@('SOCKET', 'BarlowCondensed-ExtraBold.ttf'), @('SET', 'BarlowCondensed-Light.ttf'))
    Tagline   = 'No 10 mm. As always.'
    Swatches  = @(0xFF6A13, 0xFFD400, 0x3AD0FF, 0xE83A3A)
    Hero      = 'orange'
    Shots     = @('orange', 'aod', 'yellow', 'coolant', 'redline', 'mip')
    Trio      = @('yellow', 'coolant', 'orange')
    Quad      = @('orange', 'yellow', 'coolant', 'redline')
    Large     = 'coolant'
    LargeGlow = 0x3AD0FF
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xFF6A13
    Dark      = $true
    Night     = @(0x2B2D30, 0x121314)
    Muted     = 0x8D939A
}
