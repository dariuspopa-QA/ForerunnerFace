# Store images for Pulse Rings (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Pulse Rings has no demo build: shot.ps1 adds ShotData (Sat 11 Oct 10:08:42, 8,412 steps,
# HR 58, battery 84 %) to a scratch copy. AccentColor: 0 Lime, 1 Ice blue, 2 Orange, 3 Pink,
# 4 White; BgStyle 1 Orbits ... 6 Rays.
$Shots = [ordered]@{
    'lime'   = @{}
    'aod'    = @{ Aod = $true }
    'ice'    = @{ Props = 'AccentColor=1;BgStyle=2'; Hour = 7; Min = 42 }
    'orange' = @{ Props = 'AccentColor=2;BgStyle=5;TimeWeight=2'; Hour = 18; Min = 25 }
    'pink'   = @{ Props = 'AccentColor=3;BgStyle=1'; Hour = 21; Min = 37 }
    'mip'    = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(@('PULSE', 'Bahnschrift SemiBold Condensed'), @('RINGS', 'Bahnschrift Light Condensed'))
    Tagline   = 'Body Battery, heart rate and steps in rings.'
    Swatches  = @(0xB6F24A, 0x5AC8FA, 0xFF9F0A, 0xFF6B9D, 0xF2F2F7)
    Hero      = 'lime'
    Shots     = @('lime', 'aod', 'ice', 'orange', 'pink', 'mip')
    Trio      = @('ice', 'orange', 'lime')
    Quad      = @('lime', 'ice', 'orange', 'pink')
    Large     = 'pink'
    LargeGlow = 0xFF6B9D
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xB6F24A
    Dark      = $true
    Night     = @(0x2A2A2E, 0x111113)
    Muted     = 0x8E8E93
}
