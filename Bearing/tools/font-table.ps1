# Bearing fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Time: the reference's hairline digits (cap height ~104 design px). Label: battery %, steps and the picked fields' labels and values.
$fonts = @(
    @('Time', 'time', 'Outfit-ExtraLight.ttf', 140, 0, $digits),
    @('Label', 'label', 'SpaceGrotesk-Light.ttf', 22, 15, ($upper + $lower + $digits + ' ,.:%-/' + $degree))
)
