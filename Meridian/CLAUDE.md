# Meridian — Garmin watch face

Design source: the "Meridian — Garmin Watch Face" canvas, https://claude.ai/artifact/GSKwTd2x7Nkere9XQwKjk4
(artboards Main, Settings, Variants). The face follows Main.dc.html at 454 px 1:1.

## Concept

A 24-hour dial with noon at the top and midnight at the bottom: the sun's arc from sunrise to
sunset (done part bright, rest dim), the sleep window from the user profile's bed/wake times,
hour ticks with 00/06/12/18, and a now-marker in the accent. Or, by setting, three activity
rings (steps / step goal, weekly intensity minutes / goal, floors / goal). In the middle: date
(weekday in the accent), heavy hours + light minutes (optional seconds), one focus metric
(Body Battery, steps, heart rate or stress) with four mini bars, and a bottom line (smart: sunset
countdown in daylight, else weather, else next calendar event).

Deviations from the mockup: the dim grey is 0xA3A09A (mockup 0x8E8B85, too faint); dial labels
sit at r 160 (mockup 165) because the labels are larger; on touch watches a tap on a bar switches the focus metric
(`onFacePress`); the Focus setting covers watches without touch. The MIP theme (64 colours) is the
mockup's, set in `onLayout`.

## Settings

AccentColor, RingMode (0 day, 1 activity), Focus (0-3, 4 respiration), BarBattery / BarSteps /
BarHeart / BarStress / BarResp (which metrics get a mini bar: the mockup's "Focus metrics" checkboxes),
BottomLine (0 smart, 1 sunset, 2 weather, 3 event), ShowSeconds, AodRing. A tapped bar is stored as
`tapFocus`; phone Focus vs tap: whichever changed last (`FaceEditor.pick("edFocus", ...)`). On-watch editor: style = ring mode, accent,
and two data slots (FaceCore `FaceSlots`): 1 = the focus row, 2 = the bottom line. A picked system
field replaces the face's own text there (`focusRow` / `lineOf`; the line shows `LABEL value`
without an icon, and no bar is in the accent); with no field, or before it has a value, the face
shows its own. The Value and Label fonts carry letters and `.:/%°()` so picked fields render; a
row still too wide drops letter-spacing, then takes a system font. Meridian's `applyEditor` doesn't
call `FaceCoreView.applyEditor`, so it and `loadSettings` call `applySlots` themselves.

Time and date, as in ApexFace 1.0.2: the time follows the watch's 12 / 24 h setting
(`FaceKit.hourText`, 12 h unpadded, no AM/PM). DateFormat: 0 Watch (default; month first if
the watch uses miles, else day first: Connect IQ has no API for the date order), 1 the
mockup's `SAT 10 OCT` look, 2 `MON 28-09-2026`, 3 `MON 09-28-2026` (`FaceKit.dateFormat`
/ `dateText`). The Date fonts carry a `-` glyph for the numeric forms.

## Project layout (shared by Meridian, Tide, Terrain, Bloom)

- `source/FaceView.mc`: the whole face, drawn procedurally in design pixels (454 x 454) times
  `width / 454`. `FaceView` extends `FaceCoreView`. The shared code (FaceKit, FaceFormat, FaceData, FaceEditor,
  base view and app) lives once in `../FaceCore` (see `FaceCore/CLAUDE.md`), on `base.sourcePath` in
  both jungles. `source/<Name>Test.mc` tests only this face: every display mode and setting value.
- Products: every round watch on API 5.0+, 66 of them, 218-466 px, AMOLED and MIP (as ApexFace;
  `FaceCore/tools/products.ps1`, see "Every round watch" in `FaceCore/CLAUDE.md`). The on-watch
  editor config is in `resources/configs/watchface.xml` (used where the firmware has the editor).
- Fonts: Google Fonts (OFL) turned into Connect IQ bitmap fonts per screen size by
  `tools\make-fonts.ps1` (sizes and glyphs in `tools/font-table.ps1`, TTFs in `tools/fonts/`),
  output in `resources-round-<W>x<W>/fonts/`. Each font's line box runs from cap top to the
  lowest ink, so `TEXT_JUSTIFY_VCENTER` centres digits and capitals. Small mono text is a few px
  larger than in the mockup so it reads on the watch. Letter-spacing is drawn glyph by glyph
  (`FaceKit.drawTracked`).
- Always-On (AMOLED), as ApexFace: date (weekday in a dimmed accent), light hours, dim minutes,
  four major ticks, and with AodRing the day dial or the activity rings as 3 px hairlines. Moved
  by `AOD_SHIFTS` (up to 10 px), searched for Meridian's digits with `tools\aod-optimize.ps1`
  (offline score 4040 with ApexFace's pattern, 1151 now). Measured on the fr970 simulator with
  `ApexFace\tools\aod-burnin.ps1` over 8 minutes (16:00-16:07): 6.4-6.9 % lit (day dial),
  9.0-9.5 % (activity rings); 140 pixels (in the time digits) stay lit longer than 3 minutes,
  down from 497 with ApexFace's pattern and 2463 with the original ±3 px shift.
- Phone settings vs the on-watch editor (ring mode, accent): the side that changed a value last
  wins (`FaceEditor.pick`, remembered in Storage).

## Build and run

    monkeyc -f monkey.jungle -o bin\<Name>.prg -y C:\Users\dariu\developer_key -d fr970

`monkey.jungle` uses live data (`source-live/FaceDemo.mc` is a no-op). `demo.jungle` swaps in
`tools/demo/FaceDemo.mc`: the mockup's time (Sat 10 Oct 16:08, 24 h) and readings, for comparing
with the mockup and for store screenshots; set `FORCE_AOD = true` there to render the Always-On
screen. Never ship a demo build.

Store package: `monkeyc -e -f monkey.jungle -o bin\<Name>.iq -y <key> -r`.
