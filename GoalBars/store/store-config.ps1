# Store images for Goal Bars (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Goal Bars has no demo build: shot.ps1 adds ShotData (Sat 11 Oct 10:08:42, 8,412 steps,
# 12 floors, HR 58, battery 84 %) to a scratch copy. AccentColor: 0 Lime, 1 Ice blue,
# 2 Orange, 3 Pink, 4 White; Layout 0 Stacked, 1 Classic; BgStyle 7 Aurora, 8 Deep Space.
$Shots = [ordered]@{
    'lime'    = @{}
    'aod'     = @{ Aod = $true }
    'classic' = @{ Props = 'Layout=1;AccentColor=1'; Hour = 7; Min = 42 }
    'aurora'  = @{ Props = 'AccentColor=3;BgStyle=7'; Hour = 18; Min = 25 }
    'space'   = @{ Props = 'Layout=1;AccentColor=2;BgStyle=8'; Hour = 21; Min = 37 }
    'mip'     = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(@('GOAL', 'Bahnschrift SemiBold Condensed'), @('BARS', 'Bahnschrift Light Condensed'))
    Tagline   = 'Every goal, one bar each.'
    Swatches  = @(0xB6F24A, 0x5AC8FA, 0xFF9F0A, 0xFF6B9D, 0xF2F2F7)
    Hero      = 'lime'
    Shots     = @('lime', 'aod', 'classic', 'aurora', 'space', 'mip')
    Trio      = @('classic', 'aurora', 'lime')
    Quad      = @('lime', 'classic', 'aurora', 'space')
    Large     = 'aurora'
    LargeGlow = 0xFF6B9D
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xB6F24A
    Dark      = $true
    Night     = @(0x2A2A2E, 0x111113)
    Muted     = 0x8E8E93
}
