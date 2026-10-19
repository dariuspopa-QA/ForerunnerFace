# Changelog

## Unreleased

- A data slot in the on-watch editor: the reading after the date on the bottom line (default
  heart rate) can show Body Battery, Steps, Stress, Calories, Floors, Intensity minutes or Battery
  instead. The shift ring, boxes and band are unchanged.

## 1.0.0 (15 Oct 2026)

Store text ("What's new", also in `store/description.txt`):

> • First release, on 66 round Garmin watches (AMOLED and MIP).

Details:

- Every round watch on API 5.0+ (66 products, 218-466 px), like ApexFace: fonts for nine screen
  sizes, the on-watch editor wherever the firmware has it.
- MIP watches: no Always-On (the full face stays on, seconds only while awake); the Shop Floor
  greys drawn as neutral greys (`ink`: 0x26282B would round to navy).
- From the design (FlatRate.dc.html): the repair order on the top line, "RO 4471 · BAY 3" (new
  setting RepairOrder, 0 hides it).
- Small screens: the box labels drop their letter-spacing where they would not fit (ON CLOCK).
- Store listing: `store/description.txt`, images in `store/` (`FaceCore/tools/store-shots.ps1`).
