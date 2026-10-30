# Open work (delete items when done)

- Store signing: get the key registered to the Garmin developer account (SDK Manager, signed in) and confirm a
  Store upload passes the signature check before the first release (see `.agents/memory/store-signing.md`).
- Bearing (new compass face). On the server (2026-10-30) with Terrain's fonts standing in, it builds and passes
  42/42 tests on fr970 and fenix7 and renders like the mockup (fr970, fr265, fenix7 MIP, fr255s 218 px,
  Always-On). Still on the PC:
  1. `FaceCore\tools\make-fonts.ps1 -Face Bearing` (resources-round-*/fonts; Time 140 px, Label 22 px).
  2. Build `monkey.jungle` and `demo.jungle` for fr970; fix compile errors (`-l 3` strict typing).
  3. `run-device-tests.ps1 -Face Bearing` on the 16-watch matrix (fonts load on every screen size).
  4. `shot.ps1 -Face Bearing -Device fr970 -Demo` and compare with `Bearing/design/mockup-454.png`
     and the AOD mock (< 10 % lit), now with the real fonts (the comma in "8,560", time size).
  5. Show Darius the capture; then `store-shots.ps1 -Face Bearing`, finish-face-change skill.
