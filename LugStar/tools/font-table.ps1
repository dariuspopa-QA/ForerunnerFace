# Lug Star fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Barlow Condensed stands in for the mockup's Big Shoulders Display.
$fonts = @(
    @('Seq', 'seq', 'BarlowCondensed-ExtraBold.ttf', 23, 18, $digits),
    @('Date', 'date', 'BarlowCondensed-SemiBold.ttf', 18, 15, ($upper + $digits + ' -')),
    @('Label', 'label', 'BarlowCondensed-SemiBold.ttf', 14, 13, ($upper + ' ')),
    @('Count', 'count', 'BarlowCondensed-ExtraBold.ttf', 26, 20, ($upper + $digits + ' /,-' + $middot))
)
