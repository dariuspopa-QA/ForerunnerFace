# Changelog

## 1.0.4

Store text ("What's new", also in `store/description.txt`):

> • New look: the face uses Roboto again, as in the first version, with lighter hours.
> • Larger date, data fields and arc value; the time keeps its size.
> • New option: a colon between hours and minutes. Turn on "Colon between hours and minutes" in the face's settings in the Connect IQ app, or pick the "APEX with colon" style in the on-watch editor.
> • More data fields in the Connect IQ app, the same as on the watch: Intensity minutes, Pulse Ox, Respiration, Sleep score, VO2 max (run and bike), Pressure, Weekly run distance and Solar intensity.
> • On-watch editor: the data you scroll to is shown right away, and the left field stays in place while you edit it.

Details (since 1.0.3). Test builds of this release were numbered 1.1.0–1.3.0 (local tags
`ApexFace/v1.1.0` … `v1.3.0`, sideloaded only, never published):

- Typefaces as in the 1.0.0 build: time in Roboto Condensed (hours Bold, minutes Regular),
  date and labels in Roboto Regular, field and arc values in Roboto Condensed Bold;
  always-on time in Roboto Condensed Light. Replaces the Barlow Condensed (ExtraBold hours
  were too heavy on the watch) and DM Mono of 1.0.1–1.0.3. Bitmap fonts generated from the
  static hinted Roboto TTFs (googlefonts/roboto, Apache 2.0) for all 9 screen sizes.
- Sizes (454 px design): time 156 px (the same digit height as Barlow at 164 px; Roboto
  Condensed is wider), date 22 → 26 px, field values 28 → 34 px, field labels 16 → 18 px,
  arc value 26 → 32 px, arc label 14 → 16 px. Other screens scale with their width; text at
  its minimum size stays as it was (labels on 218–260 px, the arc label up to 280 px, the
  date on 218 px). Layout: date at y 94, time at y 196, separator at 280, field labels /
  values at 302 / 334, arc value at 386. Date letter spacing 3 → 2 px so it fits the arc.
- Colon: new `TimeColon` setting (off by default) and editor style 2 "APEX with colon";
  whichever was changed last wins. Drawn in the minutes' font and colour, centred on the
  digits; hours and minutes move apart to make room for it.
- Phone settings: field ids 17–25 (Intensity minutes, Pulse Ox, Respiration, Sleep score,
  VO2 max run / bike, Pressure, Weekly run distance, Solar intensity), read through the
  same Complications data the editor uses; types a watch lacks show `--`. Pressure in hPa
  without the unit, weekly run distance in km or mi with one decimal.
- Fix (editor): the slot being edited showed the previously selected type. The editor asks
  for the slot's drawable (`getComplicationDrawable`) with the type just scrolled to before
  it reports the edit; the face now takes the type from that `ComplicationRef`.
- Fix (editor): the left field disappeared while being edited. The editor asks for the slot
  before the face has laid out its fields (it now gets its column's design box), and it
  zooms the slot around the centre of that box while the face drew the field at its layout
  position, which threw it off the screen; `drawSlot` now draws a field centred on its box.
- Tests: date and time (with and without colon) inside the arc and the longest arc label
  clear of the ticks on every screen size; the new fields round-trip between setting id
  and editor type; the editor box is centred on its field; the resource check accepts
  on / off settings (402 checks).

## 1.0.3

Store text ("What's new", also in `store/description.txt`):

> • Fixes a crash that could close the face when you returned to it, for example after an activity, a notification or a sync.

Details (since 1.0.2):

- Fix: fatal `Invalid Value` in `getTextWidthInPixels` while drawing the arc label
  (fr970 crash log, 1.0.1). On API 4+ `loadResource` returns fonts as graphics pool
  references the watch may purge; drawing with one it can't bring back can't be caught.
  `loadFonts` now keeps the resources themselves (system fonts if one won't load), and the
  cached ring is drawn from `get()`, falling back to direct drawing (also when the pool
  is too full to allocate it, as on the Venu 2 simulator with the fonts held).
- New test `fontsAreHeldAsResources` (fails on 1.0.2).
- No visible change.

## 1.0.2

Store text ("What's new", also in `store/description.txt`):

> • The time now follows your watch's 12-hour / 24-hour setting, including sunrise and sunset.
> • The date follows your watch too: MM-DD-YYYY if your watch uses miles, DD-MM-YYYY if it uses kilometres, with the weekday in front.
> • Prefer another date style? Pick DD-MM-YYYY, MM-DD-YYYY or the classic MON 28 SEP under Date format in the face's settings in the Connect IQ app.

Details (since 1.0.1):

- Time: always follows `DeviceSettings.is24Hour` (re-read once a minute); was always 24 h.
  In 12 h the hours are 1–12 without a leading zero and no AM/PM marker; the Sunrise /
  Sunset fields follow it (`7:12`).
- New `DateFormat` setting: 0 Watch (default), 1 `MON 28 SEP` (the 1.0.1 look),
  2 `MON 28-09-2026`, 3 `MON 09-28-2026`. Connect IQ has no API for the watch's date order,
  so Watch infers it from the distance units (statute → month first).
- Visible change on update: the default date switches from `MON 28 SEP` to the numeric form,
  and 12 h watches now show 12 h time.
- The date font (`Mono22`) gains a `-` glyph on every screen size; no other font changes.
- Tests for the new formats; the date-glyph test covers all three date styles.

## 1.0.1

Store text ("What's new", also in `store/description.txt`):

> • New typefaces: the time now uses a true heavy/thin condensed pair (hours bold, minutes light), with crisp labels, each sized for your watch's screen.
> • Night mode: a red palette that's easy on your eyes in the dark. Off, On, or Auto between your sleep and wake times. Find it in the face's settings in the Connect IQ app.
> • MIP watches (fēnix 7/8 Solar, Forerunner 255/955, Enduro 3 and others) now keep the seconds when your wrist is down.
> • Better burn-in protection in always-on mode on AMOLED watches.
> • The on-watch editor only offers Sleep score on watches that have it.
> • Fixes a crash when the Recovery field was selected on watches that don't track recovery time (Venu 2, Venu 2S, vívoactive 6, Approach S50).

Details (since the 1.0.0 build of 8 Oct):

- Fonts: Barlow Condensed (800 / 200 / 300 / 600) and DM Mono bitmap fonts replace the system
  stand-ins, generated for each of the 9 screen sizes (`tools/make-fonts.ps1`). Small screens
  get minimum sizes and crisp 1-bit glyphs on MIP; about 4 KB of memory.
- Night mode: new `NightMode` setting (Off / Auto / On) with the red palette; Auto uses the
  user profile's sleep and wake times (adds the `UserProfile` permission). Watches with
  Garmin's Red Shift already tint the face; the setting is for the others.
- MIP low power: `onPartialUpdate` redraws the seconds hand and trail once a second, clipped
  to a small box to stay within the power budget.
- Always-on (AMOLED): time, date and ticks move by at least 14 px across and down over every
  4 minutes, in a pattern chosen by an offline search. On fr970 frames about 5.6 % of the
  screen is lit (limit 10 %), and 16 pixels can stay lit 4–5 minutes (limit 3, older models).
- On-watch editor: watches whose firmware lacks the Sleep score data type (43 of the 66) get a
  list without it (`editor-basic`).
- Fix: recovery time, floors, stress score and weekly intensity minutes are checked before
  use; watches without them show `--` instead of crashing.
- Version number set in the manifest (1.0.1).
- Testing (no change on the watch): per-watch tests on 16 watches covering every screen size,
  Connect IQ API version and editor variant; 378 resource checks.

## 1.0.0 (8 Oct)

First release on 66 round watches (218–466 px, AMOLED and MIP): huge hours/minutes time,
270° arc and three configurable data fields, on-watch editor and phone settings, 10 accent
colours, always-on mode with burn-in shifting. System fonts as stand-ins.
