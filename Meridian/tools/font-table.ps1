# Meridian fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Small mono text is enlarged from the canvas mockup (15 -> 19, 12/13 -> 15/17 px):
# the mockup's sizes are hard to read on the watch.
$fonts = @(
    @('Hours', 'hours', 'SpaceGrotesk-Bold.ttf', 112, 0, $digits),
    @('Minutes', 'minutes', 'SpaceGrotesk-Light.ttf', 112, 0, $digits),
    @('Value', 'value', 'SpaceGrotesk-Medium.ttf', 32, 20, ($digits + ',-')),
    @('Date', 'date', 'IBMPlexMono-Regular.ttf', 19, 15, ($upper + $digits + ' -')),
    @('DateBold', 'date_bold', 'IBMPlexMono-Medium.ttf', 19, 15, $upper),
    @('Label', 'label', 'IBMPlexMono-Regular.ttf', 15, 13, ($upper + $lower + $digits + ' /%-')),
    @('Line', 'line', 'IBMPlexMono-Regular.ttf', 17, 14, ($ascii + $degree + $middot)),
    @('Seconds', 'seconds', 'IBMPlexMono-Medium.ttf', 24, 18, $digits)
)
