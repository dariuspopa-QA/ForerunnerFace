# Changelog

## Unreleased (1.0.0)

- New face from Darius's design (`design/design-source.jpg`, measured into `design/mockup-454.png`):
  ultra-thin time (hours white, minutes in the accent), two-dot colon, 60-tick ring with accent
  five-minute ticks and long 12 / 3 / 6 / 9 ticks, north triangle, battery above and steps below.
- Its own digit fonts (`tools/fonts/BearingDigits-*.ttf`, made by `tools/digits/build_digits.py`):
  no Google font matched the design's ultralight 1, 0, 4, 7 closely, so they are traced from it and
  the other digits drawn in the same style.
- Two data slots in the on-watch editor (battery and steps by default); accent colours Ice, Mint,
  Amber, Rose. Always-On: thin time, north triangle and long ticks, dimmed and shifting.
- Every round watch on API 5.0+ (66 products, 218-466 px, AMOLED and MIP).
