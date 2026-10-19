# Changelog

## Unreleased

- Data slots in the on-watch editor (see `store/description.txt`, Customise).

## 1.0.0 (15 Oct 2026)

Store text ("What's new", also in `store/description.txt`):

> • First release, on 66 round Garmin watches (AMOLED and MIP).

Details:

- Every round watch on API 5.0+ (66 products, 218-466 px), like ApexFace: fonts for nine screen
  sizes, the on-watch editor wherever the firmware has it.
- MIP watches: no Always-On (the full face stays on, seconds only while awake); the Shop Floor
  greys drawn as neutral greys (`ink`: 0x26282B would round to navy).
- Small screens: a short version of the fault text ("NO 10MM SOCKET") where the full one would
  not fit the box; HH:MM without seconds while a MIP watch sleeps.
- Store listing: `store/description.txt`, images in `store/` (`FaceCore/tools/store-shots.ps1`).
