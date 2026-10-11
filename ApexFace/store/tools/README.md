# Store image generator

Regenerates `store/*.png` from real simulator renders of the face, with a fixed time
(Mon 28 Sep) and representative readings (HR 58, steps 8,214, ...) instead of live sensors.
The drawing code is the face's own.

1. Make a scratch folder and copy into it: `manifest.xml`, `monkey.jungle`, `resources/`,
   `resources-round-*/`, `editor-full/`, `editor-basic/`, and `source/` without `*Test.mc`.
2. Copy `ShotSamples.mc.txt` to `<scratch>/source/ShotSamples.mc`, `devshot.ps1` into the
   scratch folder, and run `perl patch.pl <scratch>` (re-copy the sources before patching again;
   the patch is not idempotent).
3. Build each variant (`-BuildOnly`), e.g.
   - volt:    `devshot.ps1 -Device fr970 -BuildOnly -Tag _volt`
   - aod:     `... -Tag _aod -Aod`
   - ember:   `... -Tag _ember -Accent 0xFF5A1F -Fields "3, 4, 12" -Arc 1 -Hour 18 -Min 42 -Sec 12`
   - glacier: `... -Tag _glacier -Accent 0x4FD1FF -Numerals 0xCFE3FF -Fields "5, 8, 9" -Arc 2 -Hour 6 -Min 55 -Sec 48`
   - signal:  `... -Tag _signal -Accent 0xFF3D7F "-Numerals:-1" -Fields "0, 13, 14" -Arc 5 -Hour 21 -Min 37 -Sec 5`
   - night:   `... -Tag _night -Night -Hour 23 -Min 14 -Sec 40`
   - mip:     `devshot.ps1 -Device fenix7 -BuildOnly -Tag _mip`
4. With the simulator open, launch each from PowerShell (a hidden or detached launch does not
   switch the simulator's device):
   `Start-Process monkeydo.bat -ArgumentList bin\dev_fr970_volt.prg, fr970 -NoNewWindow -RedirectStandardOutput log.txt`,
   wait ~20 s, then `devshot.ps1 -Device fr970 -Out face\volt.png` saves the round display.
   If the simulator stays on its loading triangle after many launches, restart it.
5. `compose.ps1 -Faces face -Out <repo>\store`

The same build + capture steps check any product's layout (`-Device <id>`), and Always-On
frames for consecutive minutes (`-Aod -Min <m>`) feed `tools\aod-burnin.ps1`.

## Showcase screenshots (face on a watch)

`compose-showcase.ps1 -Faces face -Out <repo>\store` puts the face captures (volt, ember,
glacier, signal, night, aod) into a procedurally drawn generic watch (no Garmin product
imagery or branding) in a studio style: `store/showcase/` (five 500 x 500 screenshots and a
1440 x 720 hero). Save the script as UTF-8 with BOM (Windows PowerShell 5.1 reads it as ANSI
otherwise).
