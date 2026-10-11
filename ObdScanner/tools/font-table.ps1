# OBD Scanner fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# IBM Plex Mono stands in for the mockup's Share Tech Mono.
$fonts = @(
    @('Head', 'head', 'IBMPlexMono-Medium.ttf', 16, 14, ($upper + $digits + ' -' + $middot)),
    @('Time', 'time', 'IBMPlexMono-Regular.ttf', 64, 0, ($digits + ':')),
    @('Date', 'date', 'IBMPlexMono-Regular.ttf', 16, 14, ($upper + $digits + ' -')),
    @('Row', 'row', 'IBMPlexMono-Regular.ttf', 20, 16, ($upper + $lower + $digits + ' .%-')),
    @('Small', 'small', 'IBMPlexMono-Regular.ttf', 13, 12, ($upper + $digits + ' -:')),
    @('Code', 'code', 'IBMPlexMono-Medium.ttf', 19, 16, ($upper + $digits + ' '))
)
