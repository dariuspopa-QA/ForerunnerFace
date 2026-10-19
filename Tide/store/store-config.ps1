# Store images for Tide (FaceCore/tools/store-shots.ps1, compose-store.ps1).
# Shots: the demo build (Sat 10 Oct 16:08, Body Battery 52) with these settings and readings.
$Shots = [ordered]@{
    'lagoon' = @{}
    'aod'    = @{ Aod = $true }
    'coral'  = @{ Props = 'AccentColor=0xFF7A59'; Data = 'bodyBattery=78;stress=55;steps=9200'; Hour = 21; Min = 37 }
    'lime'   = @{ Props = 'AccentColor=0xB8E05A'; Data = 'bodyBattery=30;stress=10;steps=3100'; Hour = 7; Min = 5 }
    'iris'   = @{ Props = 'AccentColor=0x8E9BFF'; Data = 'bodyBattery=88;stress=36;steps=12400'; Hour = 12; Min = 40 }
    'mip'    = @{ Device = 'fenix7' }
}
$Store = @{
    Word      = @(, @('tide', 'BricolageGrotesque-ExtraBold.ttf'))
    Tagline   = 'Your energy, as water.'
    Swatches  = @(0x3FD0C9, 0xFF7A59, 0xB8E05A, 0x8E9BFF)
    Hero      = 'lagoon'
    Shots     = @('lagoon', 'aod', 'coral', 'lime', 'iris', 'mip')
    Trio      = @('coral', 'lime', 'lagoon')
    Quad      = @('lagoon', 'coral', 'lime', 'iris')
    Large     = 'iris'
    LargeGlow = 0x8E9BFF
    Aod       = 'aod'
    AodLabel  = 'Always-on'
    Glow      = 0x3FD0C9
    Light     = @(0xEAF2F1, 0xCFDDDC)
}
