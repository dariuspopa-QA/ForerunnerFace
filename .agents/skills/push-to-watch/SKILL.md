---
name: push-to-watch
description: Build a ForerunnerFace face or app and sideload it to Darius's Garmin watch over USB (MTP). Use only when Darius asks to put a build on the watch.
---

# Push a build to the watch

Only on Darius's explicit go-ahead. The watch must be plugged in over USB.

1. Build (from the face folder; never a `demo.jungle` build):
   `monkeyc -f monkey.jungle -o bin\<Name>.prg -y C:\Users\dariu\developer_key -d <device>` (fr970 for Darius's watch).
   Never print or copy the key.
2. Copy over MTP with PowerShell (the watch has no drive letter). `CopyHere` silently keeps an existing file, so
   delete the old .prg first:

```powershell
$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)                                  # This PC
$watch = $pc.Items() | Where-Object { $_.Name -match 'Forerunner' } | Select-Object -First 1
$apps = $watch.GetFolder.ParseName('Internal Storage').GetFolder.ParseName('GARMIN').GetFolder.ParseName('Apps').GetFolder
$old = $apps.ParseName('<Name>.prg'); if ($old) { $old.InvokeVerb('delete') }
$apps.CopyHere((Resolve-Path 'bin\<Name>.prg').Path)
```

3. Wait a few seconds, then check `$apps.ParseName('<Name>.prg').Size` equals the local file size.
4. Crashes on the watch: read `GARMIN\Apps\LOGS\CIQ_LOG.YML` (and `.BAK`) the same way and map pc values with
   `bin\<Name>.prg.debug.xml` from the same build.
