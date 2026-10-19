# Changelog

## Unreleased

- Data slots in the on-watch editor (see `store/description.txt`, Customise).

## 1.0.0 (15 Oct 2026)

Store text ("What's new", also in `store/description.txt`):

> • First release, on 66 round Garmin watches (AMOLED and MIP).

Details:

- Every round watch on API 5.0+ (66 products, 218-466 px), like ApexFace: fonts for nine screen
  sizes, the on-watch editor wherever the firmware has it.
- From the design (canvas Main / Settings / Variants), now implemented: the MIP 64-colour theme
  (ink FFFFFF, dim AAAAAA, track 555555, sun FFAA00 / AA5500, sleep 00AAFF); the "Focus metrics"
  choice of which metrics get a mini bar (BarBattery, BarSteps, BarHeart, BarStress, BarResp),
  with Respiration as a fifth focus metric; tap a bar on touch watches to make it the focus.
- MIP watches: no Always-On (the full face stays on), seconds only while awake.
- Mini bars at least 3 px high (they vanished on the 218 px screen).
- Store listing: `store/description.txt`, images in `store/` (`FaceCore/tools/store-shots.ps1`).
