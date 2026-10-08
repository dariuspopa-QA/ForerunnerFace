# Store image generator

Regenerates `store/*.png` from real simulator renders of the face.

1. Copy the project (`manifest.xml`, `monkey.jungle`, `resources/`, `source/` without `*Test.mc`) to a scratch folder.
2. Copy `ShotSamples.mc.txt` to `<scratch>/source/ShotSamples.mc`, then run `perl patch.pl <scratch>`.
   This fixes the time to Mon 28 Sep and feeds representative readings (HR 58, steps 8,214, …)
   instead of live sensors. Drawing code is unchanged.
3. Copy `build.sh` and the `.ps1` files into the scratch folder, then build each variant:
   `./build.sh NAME AOD ACCENT NUMERALS F1 F2 F3 ARC HOUR MIN SEC`
   - volt:    `false 0xC8FF2E 0xF4F4EF 0 1 10 0 10 8 34`
   - aod:     `true  0xC8FF2E 0xF4F4EF 0 1 10 0 10 8 34`
   - ember:   `false 0xFF5A1F 0xF4F4EF 3 4 12 1 18 42 12`
   - glacier: `false 0x4FD1FF 0xCFE3FF 5 8 9 2 6 55 48`
   - signal:  `false 0xFF3D7F -1 0 13 14 5 21 37 5`
4. With the simulator open: `capture.ps1 -Prg bin\NAME.prg -Out raw\NAME.png`, then
   `crop.ps1 -In raw\NAME.png -Out face\NAME.png` (the display origin (162, 243) assumes the default fr970 window at 100 % scaling).
5. `compose.ps1 -Faces face -Out <repo>\store`

## Checking other screen sizes

`devshot.ps1 -Device <id> -BuildOnly` builds the sample-data face for any product. Launch it with
PowerShell `Start-Process monkeydo.bat -ArgumentList bin\dev_<id>.prg, <id> -NoNewWindow
-RedirectStandardOutput <log>` (a hidden or detached launch does not switch the simulator's device),
wait ~20 s, then `devshot.ps1 -Device <id> -Out dev\<id>.png` saves the round display. If the
simulator stays on its loading triangle after many launches, restart it.
