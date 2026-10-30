# Open work (delete items when done)

- Store signing: get the key registered to the Garmin developer account (SDK Manager, signed in) and confirm a
  Store upload passes the signature check before the first release (see `.agents/memory/store-signing.md`).
- Bearing (new compass face, code and mocks written 2026-10-28 on the Linux box, never compiled) – on the PC:
  1. `FaceCore\tools\make-fonts.ps1 -Face Bearing` (resources-round-*/fonts; Time 140 px, Label 22 px).
  2. Build `monkey.jungle` and `demo.jungle` for fr970; fix compile errors (`-l 3` strict typing).
  3. `run-device-tests.ps1 -Face Bearing` on the 16-watch matrix (fonts load on every screen size).
  4. `shot.ps1 -Face Bearing -Device fr970 -Demo` and compare with `Bearing/design/mockup-454.png`
     and the AOD mock (< 10 % lit); check MIP (fenix7) ticks and small screens (218 / 240 px).
  5. Show Darius the capture; then `store-shots.ps1 -Face Bearing`, finish-face-change skill.
  Editor data slots (battery / steps lines) were added 2026-10-30, also uncompiled: test them in step 3-4.
- HP server (Debian 13): Connect IQ SDK 9.2.0 + Java 21 installed 2026-10-30 (`.agents/memory/server-sdk.md`).
  Still needed: device files (Garmin login) and webkit2gtk-4.0 / libjpeg8 for SDK Manager and simulator.
