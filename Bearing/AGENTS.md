# Bearing — Garmin watch face

Design source: Darius's image `design/design-source.jpg` (25 Oct 2026, "exactly like this").
`design/mockup-454.png` is its dial cut out and scaled to 454 px; the face follows it 1:1.
Measurements (in the source image: dial centre 723,511, radii 434 x 430.5, so x * 0.523 and
y * 0.527 give design px) are the constants at the top of `source/FaceView.mc`.

## Concept

A compass bezel: 60 ticks (minute ticks grey 0x737679, every fifth in the accent lightened 60 %
towards white, long ones at 12 / 3 / 6 / 9), a north triangle under 12, ultra-thin time with
the hours in white and the minutes in the accent, a two-dot colon at the centre. Battery icon
and percentage above, a short grey divider and footprints with the step count below.

Deliberate differences from the image: the tick ring is regular (the image's ticks drift by up
to ~2 degrees); the battery fill follows the real charge (the image shows about half for 78 %);
the background is one flat near-black (the image has a faint vignette).

## Fonts

`BearingDigits-Thin.ttf` (time) and `BearingDigits-Light.ttf` (readings, plus `,%-`) are this
face's own: ~190 Google thin fonts were scored against the design and none had its digits (an
SF-style ultralight: flagged 1, superellipse 0, open 4, straight 7). `tools/digits/build_digits.py`
(Python, shapely + fontTools) draws them as strokes: 1, 0, 4, 7 traced from the image, the other
digits in the same style; tabular, cap height 0.7 em. Rebuild with
`python tools/digits/build_digits.py tools/fonts`, then `tools\make-fonts.ps1`.
Label / Value (another field's name and value) are Onest Light (OFL).
The reading fonts' line box runs from the top of % to the comma's tail, so `drawReading` raises
the text by `READING_RAISE` (4.5 % of the line height) to centre the digits.

## Settings

AccentColor (Ice 0xA8D3F3 default, Mint, Amber, Rose; phone and on-watch editor).
Data slots (`FaceCore/face/FaceSlots.mc`): 1 = above the time (default Battery), 2 = below
(default Steps). Battery and steps draw their icon over the reading in either slot; another
field draws its label (accent) over its value. Types in `resources/configs/watchface.xml`.

## Project layout

As Tide / Meridian (see `FaceCore/AGENTS.md`): `source/FaceView.mc` draws everything in design
px times `width / 454`; `source/BearingTest.mc` tests only this face; `demo.jungle` swaps in
`tools/demo/FaceDemo.mc` (10:47, 78 %, 8,560 steps: the design; `BATTERY` and `FORCE_AOD`
constants for store shots). Never ship a demo build.

## Build and run

    monkeyc -f monkey.jungle -o bin\Bearing.prg -y C:\Users\dariu\developer_key -d fr970
