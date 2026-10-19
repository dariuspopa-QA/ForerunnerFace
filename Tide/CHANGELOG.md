# Changelog

## Unreleased

- Two data slots in the on-watch editor: the number at the water surface (default Body Battery)
  and the line at the bottom (default Steps) can show Heart rate, Stress, Calories, Floors,
  Intensity minutes or Battery instead. The water and bubbles still follow Body Battery and steps.

## 1.0.0 (15 Oct 2026)

Store text ("What's new", also in `store/description.txt`):

> • First release, on 66 round Garmin watches (AMOLED and MIP).

Details:

- Every round watch on API 5.0+ (66 products, 218-466 px), like ApexFace: fonts for nine screen
  sizes, the on-watch editor wherever the firmware has it.
- Watches without texture fills (Forerunner 165 / 255 / 70, vivoactive 5, Instinct 3 AMOLED,
  Approach S50, Descent G2): the dark underwater digits are drawn clipped to strips under the
  wave instead of as a textured fill, bubbles straight on the water.
- MIP watches: no Always-On (the full face stays on); near-greys drawn as neutral greys.
- Store listing: `store/description.txt`, images in `store/` (`FaceCore/tools/store-shots.ps1`).
