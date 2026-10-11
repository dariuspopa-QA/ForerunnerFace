# OBD Scanner — Garmin watch face (Shop Floor family, for mechanics)

Design source: the "Garmin Mechanic Faces" canvas, artboard Scanner.dc.html,
https://claude.ai/artifact/2EYDonV5w4WuBjmzHxMpT1. The face follows it at 454 px.

## Concept

One-colour diagnostic tester screen: time with seconds, PID table (HR, steps, battery volts, stress), the last 24 h of hourly max HR as bars, and a fault code: P0562 below 15 % battery, P0217 above stress 75, else a joke code changing every 5 s. Settings: screen colour, date format.

## Project layout

Same as Tide/Meridian: `source/FaceView.mc` is the face; `FaceKit.mc`, `FaceData.mc`, `FaceEditor.mc`
are copied unchanged from Tide. `source/ShopKit.mc` (radial bars, hexagons, dashed lines, battery as
volts, Always-On shifts) is shared unchanged by the five Shop Floor faces (SocketSet, TachCluster,
ObdScanner, LugStar, FlatRate): change it in one and copy to the others. `FaceDemo.battery()` was
added to both FaceDemo modules. Fonts: Barlow Condensed (stands in for the mockup's Big Shoulders
Display) and IBM Plex Mono (for Share Tech Mono), built by `tools\make-fonts.ps1` from `tools/font-table.ps1`.
Products fr265, fr265s, fr965, fr970; on-watch editor (accent) on fr970.

## Build and run

    monkeyc -f monkey.jungle -o bin$1.prg -y C:\Users\dariu\developer_key -d fr970

`demo.jungle`: the mockup's time (Sat 11 Oct 10:08:42) and readings. Never ship a demo build.
Sideload: copy `bin$1.prg` to the watch's `GARMIN\Apps`.
