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
sit at r 160 (mockup 165) because the labels are larger; the bars can't be tapped (watch faces
get no taps outside the editor), so the focus metric is a setting; no MIP theme (all products
are AMOLED).

## Settings

AccentColor, RingMode (0 day, 1 activity), Focus (0-3), BottomLine (0 smart, 1 sunset,
2 weather, 3 event), ShowSeconds, AodRing. On-watch editor (fr970): style = ring mode, accent.

Time and date, as in ApexFace 1.0.2: the time follows the watch's 12 / 24 h setting
(`FaceKit.hourText`, 12 h unpadded, no AM/PM). DateFormat: 0 Watch (default; month first if
the watch uses miles, else day first: Connect IQ has no API for the date order), 1 the
mockup's `SAT 10 OCT` look, 2 `MON 28-09-2026`, 3 `MON 09-28-2026` (`FaceKit.dateFormat`
/ `dateText`). The Date fonts carry a `-` glyph for the numeric forms.

## Project layout (shared by Meridian, Tide, Terrain, Bloom)

- `source/FaceView.mc`: the whole face, drawn procedurally in design pixels (454 x 454) times
  `width / 454`. `source/FaceKit.mc` (geometry, text, colours, settings), `source/FaceData.mc`
  (sensor readings, read once a minute) and `source/FaceEditor.mc` (Garmin's on-watch editor) are
  copied unchanged between the four projects: change them in one and copy to the others.
- Products: fr265 (416 px), fr265s (360), fr965 and fr970 (454), all AMOLED, API 5.0+.
  The on-watch editor config is in `resources-fr970/configs/watchface.xml` (fr970 only).
- Fonts: Google Fonts (OFL) turned into Connect IQ bitmap fonts per screen size by
  `tools\make-fonts.ps1` (sizes and glyphs in `tools/font-table.ps1`, TTFs in `tools/fonts/`),
  output in `resources-round-<W>x<W>/fonts/`. Each font's line box runs from cap top to the
  lowest ink, so `TEXT_JUSTIFY_VCENTER` centres digits and capitals. Small mono text is a few px
  larger than in the mockup so it reads on the watch. Letter-spacing is drawn glyph by glyph
  (`FaceKit.drawTracked`).
- Always-On (AMOLED), as ApexFace: date (weekday in a dimmed accent), light hours, dim minutes,
  four major ticks, and with AodRing the day dial or the activity rings as 3 px hairlines. Moved
  by ApexFace's shift pattern (`AOD_SHIFTS`, up to 10 px). Measured on the fr970 simulator with
  `ApexFace\tools\aod-burnin.ps1` over 8 minutes: 6.4-6.9 % lit (day dial), 9.0-9.5 %
  (activity rings); 497 pixels (in the time digits) stay lit longer than 3 minutes, down from
  2463 with the old ±3 px shift.
- Phone settings vs the on-watch editor (ring mode, accent): the side that changed a value last
  wins (`FaceEditor.pick`, remembered in Storage).

## Build and run

    monkeyc -f monkey.jungle -o bin\<Name>.prg -y C:\Users\dariu\developer_key -d fr970

`monkey.jungle` uses live data (`source-live/FaceDemo.mc` is a no-op). `demo.jungle` swaps in
`tools/demo/FaceDemo.mc`: the mockup's time (Sat 10 Oct 16:08, 24 h) and readings, for comparing
with the mockup and for store screenshots; set `FORCE_AOD = true` there to render the Always-On
screen. Never ship a demo build.

Store package: `monkeyc -e -f monkey.jungle -o bin\<Name>.iq -y <key> -r`.
