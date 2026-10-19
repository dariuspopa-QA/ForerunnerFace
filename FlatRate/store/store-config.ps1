# Store images for Flat Rate (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (Sat 11 Oct, default shift 07:00-15:00 with a break at 12:00) with
# the mockup's repair order and these settings.
$Shots = [ordered]@{
    'hivis'   = @{ Props = 'RepairOrder=4471' }
    'aod'     = @{ Props = 'RepairOrder=4471'; Aod = $true }
    'yellow'  = @{ Props = 'AccentColor=0xFFD400;RepairOrder=4502;JobName=TIMING BELT + PUMP'; Hour = 14; Min = 31 }
    'orange'  = @{ Props = 'AccentColor=0xFF6A13;RepairOrder=4488;Bay=7;JobName=CLUTCH SWAP'; Hour = 6; Min = 42 }
    'coolant' = @{ Props = 'AccentColor=0x3AD0FF;RepairOrder=4471;JobName=AC RECHARGE'; Hour = 12; Min = 25 }
    'mip'     = @{ Device = 'fenix7'; Props = 'RepairOrder=4471' }
}
$Store = @{
    Word      = @(@('FLAT', 'BarlowCondensed-ExtraBold.ttf'), @('RATE', 'BarlowCondensed-Light.ttf'))
    Tagline   = 'Your shift, on the clock.'
    Swatches  = @(0xD7FF1F, 0xFFD400, 0xFF6A13, 0x3AD0FF)
    Hero      = 'hivis'
    Shots     = @('hivis', 'aod', 'yellow', 'orange', 'coolant', 'mip')
    Trio      = @('orange', 'coolant', 'hivis')
    Quad      = @('hivis', 'yellow', 'orange', 'coolant')
    Large     = 'yellow'
    LargeGlow = 0xFFD400
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xD7FF1F
    Dark      = $true
    Night     = @(0x2B2D30, 0x121314)
    Muted     = 0x8D939A
}
