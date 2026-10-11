# Flat Rate — Garmin watch face (Shop Floor family, for mechanics)

Design source: the "Garmin Mechanic Faces" canvas, artboard FlatRate.dc.html,
https://claude.ai/artifact/2EYDonV5w4WuBjmzHxMpT1. The face follows it at 454 px.

## Concept

Shift clock: the ring fills over the shift (last tenth red), ON CLOCK / BOOK (shift length) / LEFT boxes, hazard band with the next stop (start, break, end, SHIFT OVER). Phone settings: shift start, length, break, bay (0 hides), job line text, accent, date format.

## Project layout

`source/FaceView.mc` is the face (a `FaceCoreView` subclass) and `source/<Name>App.mc` a three-line
`FaceCoreApp` subclass. Everything shared lives once in `../FaceCore` (see `FaceCore/CLAUDE.md`):
`FaceCore/source` (FaceKit, FaceData, FaceEditor, base view and app, core tests) and `FaceCore/shop/ShopKit.mc`
(radial bars, hexagons, dashed lines, battery as volts), both on `base.sourcePath` in `monkey.jungle` and
`demo.jungle`. Never copy them back into `source/`. `FaceDemo.battery()` was
added to both FaceDemo modules. Fonts: Barlow Condensed (stands in for the mockup's Big Shoulders
Display) and IBM Plex Mono (for Share Tech Mono), built by `tools\make-fonts.ps1` from `tools/font-table.ps1`.
Products fr265, fr265s, fr965, fr970; on-watch editor (accent) on fr970.

## Build and run

    monkeyc -f monkey.jungle -o bin$1.prg -y C:\Users\dariu\developer_key -d fr970

`demo.jungle`: the mockup's time (Sat 11 Oct 10:08:42) and readings. Never ship a demo build.
Sideload: copy `bin$1.prg` to the watch's `GARMIN\Apps`.
