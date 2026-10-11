# Tide — Garmin watch face

Design source: the "Meridian — Garmin Watch Face" canvas, artboard Tide.dc.html,
https://claude.ai/artifact/GSKwTd2x7Nkere9XQwKjk4. The face follows it at 454 px 1:1.

## Concept

The screen fills with water to the Body Battery level. Wave height grows with stress
(3 + stress x 0.14 px), the back wave drifts with heart rate, every 1,000 steps adds a bubble
(up to 9). Huge Bricolage Grotesque time (hours over minutes); where the water covers it the
digits turn dark. Date at the top, Body Battery number at the surface, steps at the bottom.

How the underwater digits work: a screen-size BufferedBitmap holds the water colour, bubbles
and dark digits (rebuilt when the minute, level, bubbles or colour change). The front wave is
filled with it as a texture (`Dc.setFill(BitmapTexture)`, API 4.0+). The texture's offset maps
to the polygon's bounding-box top-left, so offsetY = the wave's highest point. A texture fill
wins over setColor, so `solid()` resets the fill before plain fills and text.
fillPolygon takes at most 64 points: the wave uses 62 + 2 corners.

Deviations from the mockup: the drift advances once per update (a quarter of the mockup's
CSS speed); bubbles don't rise (no animation between one-second updates); the Body Battery
tag is kept inside the round screen when the water is high.

## Settings

AccentColor (water colour: Lagoon, Coral, Lime, Iris). On-watch editor (fr970): accent.

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
- Always-On (AMOLED): only an outline / thin version of the face, moved a few pixels every
  minute; measured below 10 % lit pixels.

## Build and run

    monkeyc -f monkey.jungle -o bin\<Name>.prg -y C:\Users\dariu\developer_key -d fr970

`monkey.jungle` uses live data (`source-live/FaceDemo.mc` is a no-op). `demo.jungle` swaps in
`tools/demo/FaceDemo.mc`: the mockup's time (Sat 10 Oct 16:08, 24 h) and readings, for comparing
with the mockup and for store screenshots; set `FORCE_AOD = true` there to render the Always-On
screen. Never ship a demo build.

Store package: `monkeyc -e -f monkey.jungle -o bin\<Name>.iq -y <key> -r`.
