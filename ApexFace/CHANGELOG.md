# Changelog

## Unreleased

- Fix: a crash on the fr970 (Invalid Value while drawing the arc label). The fonts are now
  held by the face instead of as graphics pool references the watch can purge, and the
  cached ring is drawn from `get()`, falling back to direct drawing.

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
