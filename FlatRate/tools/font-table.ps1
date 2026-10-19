# Flat Rate fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Barlow Condensed stands in for Big Shoulders Display, IBM Plex Mono for Share Tech Mono.
$fonts = @(
    @('Time', 'time', 'BarlowCondensed-ExtraBold.ttf', 112, 0, ($digits + ':')),
    @('TimeAod', 'time_aod', 'BarlowCondensed-Light.ttf', 112, 0, ($digits + ':')),
    @('Top', 'top', 'IBMPlexMono-Regular.ttf', 16, 14, ($upper + $digits + ' ' + $middot)),
    @('Job', 'job', 'BarlowCondensed-SemiBold.ttf', 23, 18, ($upper + $digits + ' +-/&.,#!?''')),
    @('BoxLabel', 'box_label', 'BarlowCondensed-SemiBold.ttf', 13, 12, ($upper + ' ')),
    @('BoxValue', 'box_value', 'IBMPlexMono-Medium.ttf', 22, 17, ($digits + ':. h-')),
    @('Band', 'band', 'BarlowCondensed-SemiBold.ttf', 17, 15, ($upper + $digits + ': ' + $middot)),
    @('Bottom', 'bottom', 'BarlowCondensed-SemiBold.ttf', 16, 14, ($upper + $digits + ' -.,%' + $middot))
)
