# Bearing — Garmin watch face

Design source: `design/reference.png` (Darius's picture, 2026-10-28). `design/mockup-454.png` and
`mockup-aod-454.png` are 454 px mocks of `source/FaceView.mc` with the real TTFs (Pillow script, not in
the repo); compare a simulator capture with them once the face builds.

## Concept

A minimalist compass dial: 60 bezel ticks (grey, every fifth in the accent, longer at 12 / 3 / 6 / 9,
12 and 6 paler), a north triangle under 12, a hairline time (Outfit ExtraLight) with the hours in white
and the minutes in the accent, a two-dot colon. Battery (outline icon filled to the charge, percentage)
above the time; a short divider, two footprints and the step count below. The look only: there is no
live heading (a watch face can't read the compass).

Deviation from the taste notes (`.agents/memory/design-process.md`): thin time and the two small icons
are kept on purpose, they are the reference design.

## Settings

AccentColor: Ice (default 0x8CC8F0), Mint, Amber, Ember, on the phone and in the on-watch editor. No
data slots yet (the battery / steps lines could become editor slots later, as in Terrain).

## Layout, build, tests

Same layout as Terrain (`Terrain/AGENTS.md`): design pixels 454 x 454 times `width / 454`, shared code in
`../FaceCore` on `base.sourcePath`, fonts from `tools\make-fonts.ps1` (table in `tools/font-table.ps1`),
66 round products. `FaceDemo` (live no-op / `tools/demo`): time 10:47 (24 h), 8,560 steps, battery 78 %
(`FaceDemo.battery`). Always-On: the 12 hour ticks, the north triangle and the time, dimmed, moved by
`aodShift`; mock 3.9 % lit.

    monkeyc -f monkey.jungle -o bin\Bearing.prg -y C:\Users\dariu\developer_key -d fr970
    monkeyc -f monkey.jungle -o bin\Test.prg -y C:\Users\dariu\developer_key -d fr970 --unit-test
