# Fonts: hold get() results (fatal "Invalid Value")
On API 4+ `WatchUi.loadResource(Rez.Fonts.X)` returns a weak `FontReference`. If the graphics pool purges it,
`drawText` / `getTextWidthInPixels` die with "Invalid Value: Failed invoking <symbol>", which try/catch can't stop
(seen in ApexFace 1.0.1 on the fr970, 2026-10-11). Load fonts only via `FaceKit.loadFonts` / `FaceKit.strongResource`.
Don't also hold big buffered bitmaps strongly: that exhausted the simulator's pool.
Crash logs: on the watch at `GARMIN\Apps\LOGS\CIQ_LOG.YML/.BAK` (MTP); map pc values with that build's `.prg.debug.xml`.
