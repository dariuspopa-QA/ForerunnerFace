# Store image generator

Regenerates `store/*.png` from real simulator renders of the face (demo build: Sat 10 Oct and
the mockup's readings), with pinned colours. The drawing code is the face's own.

1. Make a scratch folder and copy into it: `manifest.xml`, `monkey.jungle`, `demo.jungle`,
   `resources/`, `resources-fr970/`, `resources-round-*/`, `source/`, `source-live/`, `tools/`.
2. Build each variant (`shot.ps1` rewrites the scratch `tools/demo/FaceDemo.mc`):
   - rose:  `shot.ps1 -Work <scratch> -Tag rose -Palette 0`
   - aod:   `... -Tag aod -Palette 0 -Aod`
   - sky:   `... -Tag sky -Palette 2 -Hour 7 -Min 42`
   - sage:  `... -Tag sage -Palette 1 -Highlight 0xFFD23D -Hour 10 -Min 24`
   - lilac: `... -Tag lilac -Palette 5 -Highlight 0x4FD1FF -Hour 21 -Min 37`
   - coral: `... -Tag coral -Palette 3 -Highlight 0xFFD23D -Hour 18 -Min 42`
   - gold:  `... -Tag gold -Palette 4 -Highlight 0xFF5AC8 -Hour 12 -Min 30`
   - aqua:  `... -Tag aqua -Palette 6 -Hour 6 -Min 55`
   - pearl: `... -Tag pearl -Palette 7 -Highlight 0xFF4A4A -Hour 23 -Min 14`
   Palette indices follow `FaceView.PALETTES`; `-Palette -1 -Highlight -1` uses the settings.
3. With the simulator open, delete the simulator's stored settings for the app first
   (`%TEMP%\com.garmin.connectiq\GARMIN\APPS\SETTINGS\BLOOM_DEMO.SET`; otherwise old
   values such as the date format survive), then launch each from PowerShell:
   `Start-Process monkeydo.bat -ArgumentList <scratch>\bin\shot_fr970_rose.prg, fr970 -NoNewWindow -RedirectStandardOutput log.txt`,
   wait ~20 s, and `shot.ps1 -Work <scratch> -Device fr970 -Out store\faces\rose.png`.
4. `compose.ps1 -Faces store\faces -Out store` (icon, cover, screenshots, showcase, hero).
   Keep the script UTF-8 with BOM (Windows PowerShell 5.1).

`store/faces/` holds the captures used for the current images (plus `custom.png`, a
`CustomColor` #7A5CFF + cyan highlight test through the real settings path, and
`fr265s.png`, the 360 px layout).
