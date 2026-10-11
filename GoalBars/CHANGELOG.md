# Changelog

## 1.0.0

First numbered release (earlier builds had no version).

Store text ("What's new"):

> • Settings from the Connect IQ app now work on the Forerunner 970 too. Whichever you changed last, the phone or the on-watch editor, is what the face shows.
> • Wrist-down mode is calmer and easier on the screen: gray time, slightly smaller, with the hour ticks and the date in both layouts.
> • In 12-hour time the hours no longer have a leading zero ("9:41").
> • The MON 28 SEP date now shows the month in the Stacked layout too.
> • New setting: Active calories goal (300, 500, 750 or 1000 kcal).

Details:

- fr970: `loadSettings()` used to re-apply the editor's style, accent and bars over the phone
  settings every time. Now a phone change stores the editor's state (`PhoneOverEditor` in
  `Application.Storage`) and the phone settings hold until the editor's choices differ from it.
  The bottom field has no phone setting and always follows the editor. "Move alert" (no
  complication type) can now be picked from the phone on the fr970.
- Always-on: no accent color (minutes `0x4A4A4E`), time at 86 % size, 12 dim hour ticks inset
  by the burn-in shift, date in Stacked as well (still under "Show date in always-on mode"),
  and never drawn while the on-watch editor is open.
- `hourString`: 24 h zero-padded, 12 h 1–12 unpadded in both layouts.
- New `CaloriesGoal` property (default 500, as before).
