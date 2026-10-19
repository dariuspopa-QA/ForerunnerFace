# Store images for Minimal Face (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Minimal Face has no demo build: shot.ps1 adds ShotData (Sat 11 Oct 10:08:42, 8,412 steps,
# HR 58, battery 84 %) to a scratch copy. AccentColor: 0 Lime, 1 Ice blue, 2 Orange, 3 Pink,
# 4 White; TimeWeight 0 Light, 1 Regular, 2 Bold; RingMetric 0 steps, 1 battery, 2 off.
$Shots = [ordered]@{
    'lime'   = @{}
    'aod'    = @{ Aod = $true }
    'ice'    = @{ Props = 'AccentColor=1;TimeWeight=1;RingMetric=1'; Hour = 7; Min = 42 }
    'orange' = @{ Props = 'AccentColor=2;TimeWeight=2;BgStyle=2'; Hour = 18; Min = 25 }
    'white'  = @{ Props = 'AccentColor=4;BgStyle=5'; Hour = 21; Min = 37 }
    'mip'    = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(@('MINIMAL', 'Bahnschrift Light Condensed'))
    Tagline   = 'The time, a ring, two fields.'
    Swatches  = @(0xB6F24A, 0x5AC8FA, 0xFF9F0A, 0xFF6B9D, 0xF2F2F7)
    Hero      = 'lime'
    Shots     = @('lime', 'aod', 'ice', 'orange', 'white', 'mip')
    Trio      = @('ice', 'orange', 'lime')
    Quad      = @('lime', 'ice', 'orange', 'white')
    Large     = 'orange'
    LargeGlow = 0xFF9F0A
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xB6F24A
    Dark      = $true
    Night     = @(0x2A2A2E, 0x111113)
    Muted     = 0x8E8E93
}
