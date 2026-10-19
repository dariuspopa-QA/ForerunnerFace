# Tach Cluster — Garmin watch face (Shop Floor family, for mechanics)

Design source: the "Garmin Mechanic Faces" canvas, artboard Tach.dc.html,
https://claude.ai/artifact/2EYDonV5w4WuBjmzHxMpT1. The face follows it at 454 px.

## Concept

Rev counter 0-12: the needle is the hour (10-12 red zone), ticks light up to it. Gear = weekday (P Sunday, 1-6 Mon-Sat). LCD: time and steps as ODO. Fuel bar = watch battery, temperature bar = heart rate ((hr - 30) / 120 x 8 segments). Setting: accent. Data slots (on-watch editor): 1 = the LCD's ODO line, 2 = the caption above the hub; with no field picked they show ODO steps and "×1 HOUR · r/min". The Label and Mono fonts carry lower case and punctuation for picked fields.

## Project layout

`source/FaceView.mc` is the face (a `FaceCoreView` subclass) and `source/<Name>App.mc` a three-line
`FaceCoreApp` subclass. Everything shared lives once in `../FaceCore` (see `FaceCore/CLAUDE.md`):
`FaceCore/kit`, `FaceCore/face` (base view and app, FaceData), `FaceCore/test` and `FaceCore/shop/ShopKit.mc`
(radial bars, hexagons, dashed lines, battery as volts; tests in ShopKitTest.mc), all on `base.sourcePath` in `monkey.jungle` and
`demo.jungle`. Never copy them back into `source/`. Face tests (`source/<Name>Test.mc`) cover only this face: every display mode and every setting value. `FaceDemo.battery()` was
added to both FaceDemo modules. Fonts: Barlow Condensed (stands in for the mockup's Big Shoulders
Display) and IBM Plex Mono (for Share Tech Mono), built by `tools\make-fonts.ps1` from `tools/font-table.ps1`.
Products: every round watch on API 5.0+ (66, 218-466 px, AMOLED and MIP; see "Every round watch" in
`FaceCore/CLAUDE.md`); on-watch editor (accent) where the firmware has it, config in `resources/configs`.
Store: `store/description.txt`, images from `store/store-config.ps1` (`FaceCore/tools/store-shots.ps1`),
package `FaceCore/tools/package.ps1`, release notes in `CHANGELOG.md`.

## Build and run

    monkeyc -f monkey.jungle -o bin<Name>.prg -y C:\Users\dariu\developer_key -d fr970

`demo.jungle`: the mockup's time (Sat 11 Oct 10:08:42) and readings. Never ship a demo build.
Sideload: copy `bin<Name>.prg` to the watch's `GARMIN\Apps`.
