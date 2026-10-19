import Toybox.Lang;

// Colour rules for MIP screens (64 colours: each channel 00, 55, AA or FF). Pure, so the
// tests run anywhere; FaceCoreView.ink applies them on MIP watches only.
module FaceColor {

    // Channels this far apart still count as grey
    const GREY_SPREAD = 0x18;

    // A near-grey as one neutral grey by brightness (black below 0x1C, 0x555555, 0xAAAAAA
    // from 0x80, white from 0xD8); any other colour unchanged.
    function mipGrey(color as Number) as Number {
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8) & 0xFF;
        var b = color & 0xFF;
        var hi = r > g ? (r > b ? r : b) : (g > b ? g : b);
        var lo = r < g ? (r < b ? r : b) : (g < b ? g : b);
        if (hi - lo > GREY_SPREAD) {
            return color;
        }
        var lum = (r + g + b) / 3;
        if (lum < 0x1C) {
            return 0x000000;
        }
        if (lum < 0x80) {
            return 0x555555;
        }
        if (lum < 0xD8) {
            return 0xAAAAAA;
        }
        return 0xFFFFFF;
    }
}
