# Store images for Terrain (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (Sat 10 Oct 16:08, the mockup's 24 h of heart rate) with these settings.
$Shots = [ordered]@{
    'ember' = @{}
    'aod'   = @{ Aod = $true }
    'mint'  = @{ Props = 'AccentColor=0x3DDC97'; Data = 'stress=62;steps=3900'; Hour = 9; Min = 24 }
    'sky'   = @{ Props = 'AccentColor=0x4DA3FF'; Data = 'stress=8;steps=11200'; Hour = 22; Min = 40 }
    'amber' = @{ Props = 'AccentColor=0xF2B544'; Data = 'stress=35;steps=5600'; Hour = 12; Min = 45 }
    'mip'   = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(, @('terrain', 'Outfit-ExtraLight.ttf'))
    Tagline   = 'Your heart rate, as a landscape.'
    Swatches  = @(0xFF6A3D, 0x3DDC97, 0x4DA3FF, 0xF2B544)
    Hero      = 'ember'
    Shots     = @('ember', 'aod', 'mint', 'sky', 'amber', 'mip')
    Trio      = @('mint', 'amber', 'ember')
    Quad      = @('ember', 'mint', 'sky', 'amber')
    Large     = 'sky'
    LargeGlow = 0x4DA3FF
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0x8D9AB0
    Light     = @(0xE9ECF1, 0xCBD2DD)
}
