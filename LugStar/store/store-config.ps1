# Store images for Lug Star (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (Sat 11 Oct 10:08:42, 8,412 of 10,000 steps = 4 / 5) with these settings.
$Shots = [ordered]@{
    'yellow'  = @{}
    'aod'     = @{ Aod = $true }
    'orange'  = @{ Props = 'AccentColor=0xFF6A13'; Data = 'steps=10450'; Hour = 18; Min = 42; Sec = 12 }
    'coolant' = @{ Props = 'AccentColor=0x3AD0FF'; Data = 'steps=2400'; Hour = 7; Min = 21; Sec = 50 }
    'redline' = @{ Props = 'AccentColor=0xE83A3A'; Data = 'steps=6100'; Hour = 14; Min = 37; Sec = 5 }
    'mip'     = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(@('LUG', 'BarlowCondensed-ExtraBold.ttf'), @('STAR', 'BarlowCondensed-Light.ttf'))
    Tagline   = 'Torque your steps. 1-3-5-2-4.'
    Swatches  = @(0xFFD400, 0xFF6A13, 0x3AD0FF, 0xE83A3A)
    Hero      = 'yellow'
    Shots     = @('yellow', 'aod', 'orange', 'coolant', 'redline', 'mip')
    Trio      = @('orange', 'coolant', 'yellow')
    Quad      = @('yellow', 'orange', 'coolant', 'redline')
    Large     = 'orange'
    LargeGlow = 0xFF6A13
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xFFD400
    Dark      = $true
    Night     = @(0x2B2D30, 0x121314)
    Muted     = 0x8D939A
}
