# Store images for Bearing (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (10:47, 78 % battery, 8,560 steps: the design) with these settings and readings.
$Shots = [ordered]@{
    'ice'   = @{}
    'aod'   = @{ Aod = $true }
    'mint'  = @{ Props = 'AccentColor=0x9EE6C9'; Demo = 'BATTERY=52'; Data = 'steps=11240'; Hour = 18; Min = 25 }
    'amber' = @{ Props = 'AccentColor=0xF5C27A'; Demo = 'BATTERY=91'; Data = 'steps=2310'; Hour = 7; Min = 3 }
    'rose'  = @{ Props = 'AccentColor=0xF2A7BD'; Demo = 'BATTERY=34'; Data = 'steps=6480'; Hour = 21; Min = 58 }
    'mip'   = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(, @('Bearing', 'Onest-Light.ttf'))
    Tagline   = 'Quiet time, true north.'
    Swatches  = @(0xA8D3F3, 0x9EE6C9, 0xF5C27A, 0xF2A7BD)
    Hero      = 'ice'
    Shots     = @('ice', 'aod', 'mint', 'amber', 'rose', 'mip')
    Trio      = @('mint', 'amber', 'ice')
    Quad      = @('ice', 'mint', 'amber', 'rose')
    Large     = 'ice'
    LargeGlow = 0xA8D3F3
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xA8D3F3
    Dark      = $true
    Night     = @(0x2A2E33, 0x101315)
    Muted     = 0x8D939A
}
