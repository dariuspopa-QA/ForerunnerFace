# Monkey C / Connect IQ API findings
- `Dc.setFill(BitmapTexture)`: the texture offset is relative to the polygon's bounding box, and a texture/ARGB fill
  stays set and wins over `setColor` for later fills; reset with `setFill(0xFF000000 | color)`. drawText uses setColor.
- `fillPolygon` takes at most 64 points.
- `drawBitmap2(..., {:tintColor})` needs the bitmap declared `automaticPalette="false"` (else "Source must not use a
  color palette") and can't scale; `drawScaledBitmap` scales but can't tint. Ship PNGs at their final pixel size.
- Garmin vector fonts render ~13% smaller than the same CSS px size, and there are no Light weights (silent fallback).
- On-watch settings use Garmin's native watch face editor (API 5.1+, works sideloaded on the fr970). `Menu2`/`pushView`
  crash in faces ("Page control not allowed"); the old long-press menu was removed on purpose, don't bring it back.
- VO2 max, training status, sleep score etc. aren't in ActivityMonitor; faces get them only as editor complications.
- Phone (Connect Mobile) settings work only for Store installs, not sideloaded apps.
