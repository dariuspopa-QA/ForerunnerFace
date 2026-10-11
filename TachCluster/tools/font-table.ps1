# Tach Cluster fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Barlow Condensed stands in for Big Shoulders Display, IBM Plex Mono for Share Tech Mono.
$fonts = @(
    @('Num', 'num', 'BarlowCondensed-ExtraBold.ttf', 31, 22, $digits),
    @('Label', 'label', 'BarlowCondensed-SemiBold.ttf', 14, 13, ($upper + 'rminx' + $digits + ' /' + $middot)),
    @('Gear', 'gear', 'BarlowCondensed-ExtraBold.ttf', 36, 26, ($digits + 'P')),
    @('Lcd', 'lcd', 'IBMPlexMono-Medium.ttf', 30, 22, ($digits + ':')),
    @('Mono', 'mono', 'IBMPlexMono-Regular.ttf', 13, 12, ($upper + $digits + ' -')),
    @('Bar', 'bar', 'BarlowCondensed-SemiBold.ttf', 13, 12, ($upper + $digits + ' -'))
)
