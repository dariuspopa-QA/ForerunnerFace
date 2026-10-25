# Bearing fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# BearingDigits-*.ttf are this face's own digits (tools/digits/build_digits.py), traced from the
# design's 1, 0, 4, 7; cap height is 0.7 of the size, so 140 px = the design's 98 px time.
# ReadingTop / ReadingBottom carry the same glyphs (battery or steps can go in either slot).
# Label / Value: another data field's label and value (Onest Light, OFL).
$reading = $digits + ',%-'
$fonts = @(
    @('Time', 'time', 'BearingDigits-Thin.ttf', 140, 0, $digits),
    @('ReadingTop', 'reading_top', 'BearingDigits-Light.ttf', 23, 18, $reading),
    @('ReadingBottom', 'reading_bottom', 'BearingDigits-Light.ttf', 25, 19, $reading),
    @('Label', 'label', 'Onest-Light.ttf', 17, 14, ($upper + $digits + ' .-/%')),
    @('Value', 'value', 'Onest-Light.ttf', 24, 18, ($ascii + $degree))
)
