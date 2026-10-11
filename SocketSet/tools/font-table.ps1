# Socket Set fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Barlow Condensed stands in for the mockup's Big Shoulders Display; small labels are a
# little larger than in the mockup so they read on the watch.
$fonts = @(
    @('Time', 'time', 'BarlowCondensed-ExtraBold.ttf', 98, 0, ($digits + ':')),
    @('TimeAod', 'time_aod', 'BarlowCondensed-Light.ttf', 98, 0, ($digits + ':')),
    @('Sec', 'sec', 'BarlowCondensed-ExtraBold.ttf', 30, 22, $digits),
    @('Socket', 'socket', 'BarlowCondensed-ExtraBold.ttf', 20, 16, ($digits + '?')),
    @('Date', 'date', 'BarlowCondensed-SemiBold.ttf', 19, 16, ($upper + $digits + ' -')),
    @('Label', 'label', 'BarlowCondensed-SemiBold.ttf', 15, 13, $upper),
    @('Value', 'value', 'BarlowCondensed-ExtraBold.ttf', 27, 21, ($digits + ',.V-'))
)
