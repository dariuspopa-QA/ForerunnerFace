# Store images for OBD Scanner (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (Sat 11 Oct 10:08:42, the mockup's readings) with these settings.
# The joke code changes every 5 s: 21:37:10 shows U0100, 06:31:15 B1200.
$Shots = [ordered]@{
    'amber' = @{}
    'aod'   = @{ Aod = $true }
    'green' = @{ Props = 'AccentColor=0x7DFF6A'; Data = 'stress=82'; Hour = 17; Min = 45; Sec = 20 }
    'cyan'  = @{ Props = 'AccentColor=0x5FD3FF'; Hour = 21; Min = 37; Sec = 10 }
    'red'   = @{ Props = 'AccentColor=0xFF5A3C'; Hour = 6; Min = 31; Sec = 15 }
    'mip'   = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(@('OBD', 'IBMPlexMono-Medium.ttf'), @(' SCANNER', 'IBMPlexMono-Regular.ttf'))
    Tagline   = 'P1010: 10mm socket not found.'
    Swatches  = @(0xFFB000, 0x7DFF6A, 0x5FD3FF, 0xFF5A3C)
    Hero      = 'amber'
    Shots     = @('amber', 'aod', 'green', 'cyan', 'red', 'mip')
    Trio      = @('green', 'cyan', 'amber')
    Quad      = @('amber', 'green', 'cyan', 'red')
    Large     = 'green'
    LargeGlow = 0x7DFF6A
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0xFFB000
    Dark      = $true
    Night     = @(0x2B2D30, 0x121314)
    Muted     = 0x8D939A
}
