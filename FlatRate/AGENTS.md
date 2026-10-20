# Flat Rate — Garmin watch face (Shop Floor family, for mechanics)

Design source: the "Garmin Mechanic Faces" canvas, artboard FlatRate.dc.html,
https://claude.ai/artifact/2EYDonV5w4WuBjmzHxMpT1. The face follows it at 454 px.

## Concept

Shift clock: the ring fills over the shift (last tenth red), ON CLOCK / BOOK (shift length) / LEFT boxes, hazard band with the next stop (start, break, end, SHIFT OVER). Phone settings: shift start, length, break, bay (0 hides), job line text, accent, date format.

## Project layout

`source/FaceView.mc` is the face (a `FaceCoreView` subclass) and `source/<Name>App.mc` a three-line
`FaceCoreApp` subclass. Everything shared lives once in `../FaceCore` (see `FaceCore/AGENTS.md`):
`FaceCore/kit`, `FaceCore/face` (base view and app, FaceData), `FaceCore/test` and `FaceCore/shop/ShopKit.mc`
(radial bars, hexagons, dashed lines, battery as volts; tests in ShopKitTest.mc), all on `base.sourcePath` in `monkey.jungle` and
`demo.jungle`. Never copy them back into `source/`. Face tests (`source/<Name>Test.mc`) cover only this face: every display mode and every setting value. `FaceDemo.battery()` was
added to both FaceDemo modules. Fonts: Barlow Condensed (stands in for the mockup's Big Shoulders
Display) and IBM Plex Mono (for Share Tech Mono), built by `tools\make-fonts.ps1` from `tools/font-table.ps1`.
Products: every round watch on API 5.0+ (66, 218-466 px, AMOLED and MIP; see "Every round watch" in
`FaceCore/AGENTS.md`); on-watch editor (accent and one data slot, see "Data slots" in `FaceCore/AGENTS.md`) where the firmware has it, config in `resources/configs`.
Store: `store/description.txt`, images from `store/store-config.ps1` (`FaceCore/tools/store-shots.ps1`),
package `FaceCore/tools/package.ps1`, release notes in `CHANGELOG.md`.

## Build and run

    monkeyc -f monkey.jungle -o bin<Name>.prg -y C:\Users\dariu\developer_key -d fr970

`demo.jungle`: the mockup's time (Sat 11 Oct 10:08:42) and readings. Never ship a demo build.
Sideload: copy `bin<Name>.prg` to the watch's `GARMIN\Apps`.
