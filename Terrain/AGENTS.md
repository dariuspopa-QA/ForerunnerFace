# Terrain — Garmin watch face

Design source: the "Meridian — Garmin Watch Face" canvas, artboard Terrain.dc.html,
https://claude.ai/artifact/GSKwTd2x7Nkere9XQwKjk4. The face follows it at 454 px 1:1.

## Concept

The last 24 hours of heart rate as a mountain ridge (hourly maxima, now at the right end with
the current reading), snow down to a line set by stress (y = 250 + stress x 1.5), a flag on the
ridge at step-goal progress, a far range behind, and the sun on a dotted arc from sunrise to
sunset (a crescent moon on the same arc at night). Thin Outfit time, date and sunset/sunrise.

Heart rate per hour: `FaceData.hrHours()` reads 24 h of `SensorHistory.getHeartRateHistory`
every ten minutes and merges it with values stored in `Application.Storage` ("hrHours"), so
the ridge stays complete on watches that keep less history. Gaps are interpolated.

Deviations from the mockup: the ridge ends at x 398 (mockup 416, on the screen edge); the
"62 bpm" label sits inside the mountain under the now-dot (in the mockup it was cut off by
the edge); the sun path is dotted rather than dashed.

## Settings

AccentColor (flag: Ember, Mint, Sky, Amber). On-watch editor: accent and one data slot (the
sunset line under the time; `FaceView.slots`, see "Data slots" in `FaceCore/AGENTS.md`).

Time and date, as in ApexFace 1.0.2: the time follows the watch's 12 / 24 h setting
(`FaceKit.hourText`, 12 h unpadded, no AM/PM). DateFormat: 0 Watch (default; month first if
the watch uses miles, else day first: Connect IQ has no API for the date order), 1 the
mockup's `SAT 10 OCT` look, 2 `MON 28-09-2026`, 3 `MON 09-28-2026` (`FaceKit.dateFormat`
/ `dateText`). The Date fonts carry a `-` glyph for the numeric forms.

## Project layout (shared by Meridian, Tide, Terrain, Bloom)

- `source/FaceView.mc`: the whole face, drawn procedurally in design pixels (454 x 454) times
  `width / 454`. `FaceView` extends `FaceCoreView`. The shared code (FaceKit, FaceFormat, FaceData, FaceEditor,
  base view and app) lives once in `../FaceCore` (see `FaceCore/AGENTS.md`), on `base.sourcePath` in
  both jungles. `source/<Name>Test.mc` tests only this face: every display mode and setting value.
- Products: every round watch on API 5.0+, 66 of them, 218-466 px, AMOLED and MIP (as ApexFace;
  `FaceCore/tools/products.ps1`, see "Every round watch" in `FaceCore/AGENTS.md`). The on-watch
  editor config is in `resources/configs/watchface.xml` (used where the firmware has the editor).
- Fonts: Google Fonts (OFL) turned into Connect IQ bitmap fonts per screen size by
  `tools\make-fonts.ps1` (sizes and glyphs in `tools/font-table.ps1`, TTFs in `tools/fonts/`),
  output in `resources-round-<W>x<W>/fonts/`. Each font's line box runs from cap top to the
  lowest ink, so `TEXT_JUSTIFY_VCENTER` centres digits and capitals. Small mono text is a few px
  larger than in the mockup so it reads on the watch. Letter-spacing is drawn glyph by glyph
  (`FaceKit.drawTracked`).
- Always-On (AMOLED): only an outline / thin version of the face, moved every minute by
  `FaceKit.aodShift` (Meridian: its own searched pattern; both >= 14 px in any 4 minutes); measured below 10 % lit pixels.

## Build and run

    monkeyc -f monkey.jungle -o bin\<Name>.prg -y C:\Users\dariu\developer_key -d fr970

`monkey.jungle` uses live data (`source-live/FaceDemo.mc` is a no-op). `demo.jungle` swaps in
`tools/demo/FaceDemo.mc`: the mockup's time (Sat 10 Oct 16:08, 24 h) and readings, for comparing
with the mockup and for store screenshots; set `FORCE_AOD = true` there to render the Always-On
screen. Never ship a demo build.

Store package: `monkeyc -e -f monkey.jungle -o bin\<Name>.iq -y <key> -r`.
