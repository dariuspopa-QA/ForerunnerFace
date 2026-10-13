# Changelog

## 1.3.0

Store text ("What's new", also in `store/description.txt`):

> • New look: the face is set in Roboto again, as in the first version. Lighter hours, clearer minutes, date and data.

Details (since 1.2.1):

- Typefaces as in the 1.0.0 build (the user's preferred look): time in Roboto Condensed
  (hours Bold, minutes Regular), date and labels in Roboto Regular, field and arc values
  in Roboto Condensed Bold. Always-on: hours and minutes in Roboto Condensed Light, to keep
  the lit pixels low. Bitmap fonts generated from the static hinted Roboto TTFs
  (googlefonts/roboto, Apache 2.0).
- Sizes as in 1.2.1, except the time: 156 px, the same digit height as Barlow at 164 px
  (Roboto Condensed is wider; at 164 px the time with the colon would cross the arc).
- Colon: 26 px gap between hours and minutes (22 px before), 1 px right of centre.
- Tests: colon-width check adjusted for Roboto's colon (ink about half its advance).

## 1.2.1

Store text ("What's new", also in `store/description.txt`):

> • The time is back to its original size; the date and data fields stay larger.
> • On-watch editor: the data you scroll to is shown right away, and the first field no longer disappears while you edit it.

Details (since 1.2.0):

- Time back to 164 px (1.0 size; 176 px since 1.1.0 was too big on the watch), its row
  at y 196, centred between date and separator. Date and field sizes stay as in 1.1.0.
- Fix (editor, still in 1.2.0): the preview of the slot being edited showed the previous
  data type. The editor asks for the slot's drawable (`getComplicationDrawable`) with the
  type just scrolled to before it reports the edit, and the saved configuration can still
  hold the old one then; the face now takes the type from that `ComplicationRef`. The
  1.2.0 re-read of the configuration in `drawSlot` is gone.
- Fix (editor): the first field went blank when the editor opened on it. The editor asks
  for that slot before the face has laid out its fields, and the face returned no
  drawable; it now uses the column's design box until the layout exists.
- Screenshots with and without the colon: `dist/screenshots-1.2.1/` (not committed).

## 1.2.0

Store text ("What's new", also in `store/description.txt`):

> • On-watch editor: the data field you scroll to is now shown right away (it showed the previous choice).
> • More data fields in the Connect IQ app settings, the same as on the watch: Intensity minutes, Pulse Ox, Respiration, Sleep score, VO2 max (run and bike), Pressure, Weekly run distance and Solar intensity.
> • New style in the on-watch editor: APEX with colon, a colon between hours and minutes.

Details (since 1.1.0):

- Fix: in the on-watch editor a data slot showed the previously selected type. The editor
  draws the slot it animates right after each scroll, before the face's next update, and
  the slot was drawn from the field texts cached at that update. `drawSlot` now re-reads
  the edited configuration and recomputes the field layout first.
- Phone settings: field ids 17–25 (Intensity minutes, Pulse Ox, Respiration, Sleep score,
  VO2 max run / bike, Pressure, Weekly run distance, Solar intensity), read through the
  same Complications data the editor uses; types missing on a watch show `--`. The editor
  maps those types to the same ids, so both sides show the same label.
- Pressure shows hPa without the unit (`1013`); weekly run distance in km or mi with one
  decimal (`RUN KM` / `RUN MI`); the system reports Pa and metres.
- Editor styles: "APEX" and "APEX with colon". The colon follows whichever of the phone's
  TimeColon setting and the editor style was changed last.
- Tests: the new fields round-trip between setting id and editor type and render on every
  watch; 402 resource checks.

## 1.1.0

Store text ("What's new", also in `store/description.txt`):

> • Bigger text: the time, the date, the three data fields and the arc value are all larger and easier to read.
> • New option: a colon between hours and minutes. Turn on "Colon between hours and minutes" in the face's settings in the Connect IQ app.

Details (since 1.0.3):

- New `TimeColon` setting (on / off, default off, so the face looks as before apart from the
  sizes). The colon uses the minutes' thin weight and colour (dim in always-on), centred on the
  digits; the hours and minutes move apart to make room for it.
- Larger type (454 px design sizes): time 164 → 176 px, date 22 → 26 px, field values
  28 → 34 px, field labels 16 → 18 px, arc value 26 → 32 px, arc label 14 → 16 px. Other
  screens scale with their width. Text already at its minimum size stays as it was: labels
  on 218–260 px screens, the arc label up to 280 px and the date on 218 px.
- Layout re-fitted around the bigger time: date at y 94, time at y 202, separator at 280,
  field labels / values at 302 / 334, arc value at 386.
- The date's letter spacing goes from 3 to 2 px so the larger date still fits inside the arc.
- Fonts regenerated for all 9 screen sizes; the minutes font gains a `:` glyph.
- New per-watch tests: date and time (with and without colon, at the top corners) inside the
  arc, the longest arc label clear of the bottom ticks, and the colon setting in every mode.
- The resource check accepts on / off settings.

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
