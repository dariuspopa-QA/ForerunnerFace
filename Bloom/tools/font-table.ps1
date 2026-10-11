# Bloom fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Sizes are the canvas mockup's exactly (time 60, date 12, value 14, key 10 px); the minimums
# only apply on the 360 px screen, where pure scaling would make the mono text unreadable.
$fonts = @(
    @('Time', 'time', 'SpaceGrotesk-Bold.ttf', 60, 0, ($digits + ':')),
    @('TimeAod', 'time_aod', 'SpaceGrotesk-Light.ttf', 60, 0, ($digits + ':')),
    @('Date', 'date', 'IBMPlexMono-Medium.ttf', 12, 11, ($upper + $digits + ' -')),
    @('Value', 'value', 'IBMPlexMono-Medium.ttf', 14, 12, ($digits + 'hk.%-')),
    @('Key', 'key', 'IBMPlexMono-Regular.ttf', 10, 9, $upper)
)
