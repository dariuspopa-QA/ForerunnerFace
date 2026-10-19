# Tide fonts: @(id, file, ttf, 454 px design size, minimum px, glyphs).
# Small mono text is enlarged from the canvas mockup (14 -> 18, 13 -> 17 px).
# Tag also carries what the editor data slots show (punctuation and the degree sign of other fields' values).
$fonts = @(
    @('Time', 'time', 'BricolageGrotesque-ExtraBold.ttf', 156, 0, $digits),
    @('TimeAod', 'time_aod', 'BricolageGrotesque-ExtraLight.ttf', 136, 0, $digits),
    @('Date', 'date', 'IBMPlexMono-Regular.ttf', 18, 15, ($upper + $digits + ' -')),
    @('Tag', 'tag', 'IBMPlexMono-Medium.ttf', 17, 14, ($upper + $digits + ', -.:%/+' + $degree))
)
