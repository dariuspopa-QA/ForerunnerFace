# Tach Cluster fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Barlow Condensed stands in for Big Shoulders Display, IBM Plex Mono for Share Tech Mono.
# The dial numbers are slanted like the mockup's italic Big Shoulders (no italic file needed).
$fonts = @(
    @('Num', 'num', 'BarlowCondensed-ExtraBold.ttf', 31, 22, $digits, 'italic'),
    @('Label', 'label', 'BarlowCondensed-SemiBold.ttf', 14, 13, ($upper + $lower + $digits + ' ./%:,-' + $middot + [string][char]0xD7)),
    @('Gear', 'gear', 'BarlowCondensed-ExtraBold.ttf', 36, 26, ($digits + 'P')),
    @('Lcd', 'lcd', 'IBMPlexMono-Medium.ttf', 30, 22, ($digits + ':')),
    @('Mono', 'mono', 'IBMPlexMono-Regular.ttf', 13, 12, ($upper + $lower + $digits + ' -.,:/%')),
    @('Bar', 'bar', 'BarlowCondensed-SemiBold.ttf', 13, 12, ($upper + $digits + ' -'))
)
