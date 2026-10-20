# Simulator and toolchain gotchas
- The simulator keeps app properties between runs, so a changed default in `properties.xml` doesn't show. Delete
  `%LOCALAPPDATA%\Temp\com.garmin.connectiq\GARMIN\APPS\SETTINGS\<APP>.SET` or force the value in a scratch copy.
- PowerShell `Set-Content -Encoding utf8` writes a BOM that monkeyc rejects ("mismatched input 'import'").
- Never run two simulator scripts at once; several `monkeydo` launches back to back in one script can hang.
- Synthetic mouse input to the simulator (taps, long-press) is unreliable; test those on the real watch.
