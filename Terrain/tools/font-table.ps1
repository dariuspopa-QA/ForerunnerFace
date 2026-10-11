# Terrain fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Small mono text is enlarged from the canvas mockup (13 -> 17, 12 -> 16 px).
$fonts = @(
    @('Time', 'time', 'Outfit-ExtraLight.ttf', 92, 0, ($digits + ':')),
    @('Date', 'date', 'IBMPlexMono-Regular.ttf', 17, 14, ($upper + $digits + ' -')),
    @('Small', 'small', 'IBMPlexMono-Regular.ttf', 16, 13, ($lower + $digits + ' :-')),
    @('Flag', 'flag', 'IBMPlexMono-Medium.ttf', 16, 13, ($digits + '%-'))
)
