# Store images for Meridian (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (Sat 10 Oct 16:08, the mockup's readings) with these settings.
$Shots = [ordered]@{
    'ember'    = @{}
    'aod'      = @{ Aod = $true }
    'mint'     = @{ Props = 'AccentColor=0x3DDC97;Focus=1;BottomLine=2'; Hour = 11; Min = 24 }
    'sky'      = @{ Props = 'AccentColor=0x4DA3FF;RingMode=1;Focus=2;BottomLine=2;ShowSeconds=true' }
    'rose'     = @{ Props = 'AccentColor=0xFF5C8A;Focus=3;BottomLine=3'; Hour = 7; Min = 52 }
    'amber'    = @{ Props = 'AccentColor=0xF2B544;Focus=4;BarResp=true;BarStress=false'; Hour = 13; Min = 5 }
    'mip'      = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(@('MERI', 'SpaceGrotesk-Bold.ttf'), @('DIAN', 'SpaceGrotesk-Light.ttf'))
    Tagline   = 'Your day around the sun.'
    Swatches  = @(0xFF6A3D, 0x3DDC97, 0x4DA3FF, 0xF2F0EA, 0xF2B544, 0xFF5C8A)
    Hero      = 'ember'
    Shots     = @('ember', 'aod', 'mint', 'sky', 'rose', 'amber', 'mip')
    Trio      = @('mint', 'rose', 'ember')
    Quad      = @('ember', 'sky', 'amber', 'mip')
    Large     = 'sky'
    LargeGlow = 0x4DA3FF
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xF2B544
    Light     = @(0xF2EEE8, 0xDCD6CE)
}
