# Store images for Bearing (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (10:47, 78 %, 8,560 steps) with these settings.
$Shots = [ordered]@{
    'ice'   = @{}
    'aod'   = @{ Aod = $true }
    'mint'  = @{ Props = 'AccentColor=0x3DDC97'; Data = 'steps=3900'; Hour = 7; Min = 12 }
    'amber' = @{ Props = 'AccentColor=0xF2B544'; Data = 'steps=11200'; Hour = 18; Min = 35 }
    'ember' = @{ Props = 'AccentColor=0xFF6A3D'; Data = 'steps=6400'; Hour = 13; Min = 5 }
    'mip'   = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(, @('bearing', 'Outfit-ExtraLight.ttf'))
    Tagline   = 'True north, nothing more.'
    Swatches  = @(0x8CC8F0, 0x3DDC97, 0xF2B544, 0xFF6A3D)
    Hero      = 'ice'
    Shots     = @('ice', 'aod', 'mint', 'amber', 'ember', 'mip')
    Trio      = @('mint', 'ice', 'amber')
    Quad      = @('ice', 'mint', 'amber', 'ember')
    Large     = 'ice'
    LargeGlow = 0x8CC8F0
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0x8D9AB0
    Light     = @(0xE9ECF1, 0xCBD2DD)
}
