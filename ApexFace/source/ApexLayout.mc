import Toybox.Lang;
import Toybox.Math;

// Pure geometry and colour rules for the face, kept free of Dc access so they
// can be unit tested. Coordinates are design pixels (454 x 454).
module ApexLayout {

    // Design centre
    const C = 227.0f;

    // Arc: 270 degrees from bottom-left clockwise to bottom-right (CIQ degrees)
    const ARC_START = 225;
    const ARC_SWEEP = 270;

    // Arc readout value centre; taps below it (near the centre line) select the arc
    const READOUT_VALUE_Y = 386.0f;

    // Taps outside this radius select the arc (the rim)
    const ARC_HIT_R = 170.0f;

    // NumeralColor setting value meaning "same as the accent"
    const NUMERALS_ACCENT = -1;

    // Minor ticks and rule (arc track, separator). MIP screens show 64 colours
    // (channels 00/55/AA/FF), where the AMOLED greys would round to black.
    const MINOR_AMOLED = 0x34342F;
    const RULE_AMOLED = 0x2A2A28;
    const GREY_MIP = 0x555555;

    // [minor, rule] for the screen type.
    function ringGreys(amoled as Boolean) as [Number, Number] {
        return amoled ? [MINOR_AMOLED, RULE_AMOLED] : [GREY_MIP, GREY_MIP];
    }

    // Always-On major ticks (AMOLED only)
    const AOD_MAJOR = 0x4A4A46;

    // Night (red) palette, CLAUDE.md Colours. MIP rounds 0x3A120E to 0x550000 anyway;
    // it is set explicitly so both screen types are predictable.
    const NIGHT_RED = 0xFF4A3D;
    const NIGHT_DIM = 0xB3392E;
    const NIGHT_RULE_AMOLED = 0x3A120E;
    const NIGHT_RULE_MIP = 0x550000;
    const NIGHT_AOD_MAJOR = 0x5C1E18;   // same visual weight as AOD_MAJOR

    // Palette indices
    enum { P_ACCENT, P_NUMERALS, P_INK, P_DIM, P_MINOR, P_RULE, P_AOD_MAJOR }

    // Colours in use: the day colours from settings, or the red night palette.
    // day = [accent, numerals, ink, dim]; result is indexed by the P_* values.
    function palette(day as Array<Number>, amoled as Boolean, night as Boolean) as Array<Number> {
        if (night) {
            var rule = amoled ? NIGHT_RULE_AMOLED : NIGHT_RULE_MIP;
            return [NIGHT_RED, NIGHT_RED, NIGHT_RED, NIGHT_DIM, rule, rule, NIGHT_AOD_MAJOR];
        }
        var greys = ringGreys(amoled);
        return [day[0], day[1], day[2], day[3], greys[0], greys[1], AOD_MAJOR];
    }

    // NightMode setting values
    enum { NIGHT_OFF = 0, NIGHT_AUTO = 1, NIGHT_ON = 2 }

    // Whether a minute of the day falls in the sleep window [sleep, wake), which
    // may wrap past midnight. All values are minutes since midnight.
    function inSleepWindow(minute as Number, sleep as Number, wake as Number) as Boolean {
        if (sleep == wake) {
            return false;
        }
        if (sleep < wake) {
            return minute >= sleep && minute < wake;
        }
        return minute >= sleep || minute < wake;
    }

    // Colour at the given visual weight over the black ground.
    function blend(color as Number, weight as Float) as Number {
        var r = (((color >> 16) & 0xFF) * weight).toNumber();
        var g = (((color >> 8) & 0xFF) * weight).toNumber();
        var b = ((color & 0xFF) * weight).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // Numeral colour from the NumeralColor setting.
    function numeralColor(setting as Number, accent as Number) as Number {
        return setting == NUMERALS_ACCENT ? accent : setting;
    }

    // Pen width for a design width at the screen scale: never below 1 px (thinner
    // pens throw on small screens), whole pixels on MIP, fractional for anti-aliased AMOLED.
    function penWidth(design as Float, scale as Float, amoled as Boolean) as Numeric {
        var w = design * scale;
        if (w < 1.0f) {
            w = 1.0f;
        }
        return amoled ? w : Math.round(w).toNumber();
    }

    // Index of the system font to stand in for a design size: the tallest whose
    // line height is within 1.3x the target (line height includes leading), or the
    // smallest when none is that small (tiny labels on small MIP screens).
    function pickFont(heights as Array<Number>, targetPx as Float) as Number {
        var best = -1;
        var smallest = 0;
        for (var i = 0; i < heights.size(); i++) {
            if (heights[i] < heights[smallest]) {
                smallest = i;
            }
            if (heights[i] <= targetPx * 1.3f && (best < 0 || heights[i] > heights[best])) {
                best = i;
            }
        }
        return best >= 0 ? best : smallest;
    }

    // Half the vertical space (px) a text row needs, from its font height. Custom
    // fonts report their cap height (line box cropped to the ink), so they get half
    // of it plus a small gap; system fonts report a line height with built-in
    // leading, so a bit under half of it is enough.
    function rowExtent(fontHeight as Number, capHeight as Boolean, scale as Float) as Float {
        if (capHeight) {
            var gap = 4.0f * scale;
            return fontHeight / 2.0f + (gap < 2.0f ? 2.0f : gap);
        }
        return fontHeight * 0.425f;
    }

    // Centre y (px) of a text row under another: its design position, pushed
    // down when the two rows' extents (see rowExtent) would overlap.
    function rowBelow(aboveY as Float, designY as Float, aboveExtent as Float, extent as Float) as Float {
        var minY = aboveY + aboveExtent + extent;
        return designY > minY ? designY : minY;
    }

    // Centre y (px) of a text row over another: its design position, pulled up
    // when the two rows' extents would overlap.
    function rowAbove(belowY as Float, designY as Float, belowExtent as Float, extent as Float) as Float {
        var maxY = belowY - belowExtent - extent;
        return designY < maxY ? designY : maxY;
    }

    // CIQ end angle of the seconds trail, drawn clockwise from 12 o'clock (CIQ 90).
    function trailEnd(sec as Number) as Number {
        return 90 - sec * 6;
    }

    // Screen box [x, y, w, h] (px) covering the seconds comet at a second (r 202 -> 224,
    // round caps) plus the trail at r 226: what a partial update must redraw.
    function cometBox(sec as Number, scale as Float) as [Number, Number, Number, Number] {
        var a = clockPoint(sec * 6, 202.0f);
        var b = clockPoint(sec * 6, 227.0f);
        var margin = 3.0f;   // half the comet width + the trail pen, design px
        var x1 = (a[0] < b[0] ? a[0] : b[0]) - margin;
        var x2 = (a[0] > b[0] ? a[0] : b[0]) + margin;
        var y1 = (a[1] < b[1] ? a[1] : b[1]) - margin;
        var y2 = (a[1] > b[1] ? a[1] : b[1]) + margin;
        var left = Math.floor((C + x1) * scale).toNumber();
        var top = Math.floor((C + y1) * scale).toNumber();
        var right = Math.ceil((C + x2) * scale).toNumber();
        var bottom = Math.ceil((C + y2) * scale).toNumber();
        return [left, top, right - left, bottom - top];
    }

    // Smallest box covering two boxes.
    function unionBox(a as [Number, Number, Number, Number], b as [Number, Number, Number, Number]) as [Number, Number, Number, Number] {
        var left = a[0] < b[0] ? a[0] : b[0];
        var top = a[1] < b[1] ? a[1] : b[1];
        var right = (a[0] + a[2]) > (b[0] + b[2]) ? (a[0] + a[2]) : (b[0] + b[2]);
        var bottom = (a[1] + a[3]) > (b[1] + b[3]) ? (a[1] + a[3]) : (b[1] + b[3]);
        return [left, top, right - left, bottom - top];
    }

    // Degrees of arc fill for a 0..1 fraction; 0 without a reading.
    function arcSweep(fraction as Float or Null) as Float {
        return fraction != null ? fraction * ARC_SWEEP : 0.0f;
    }

    // Offset [dx, dy] from the centre of the point at radius r on a clock
    // angle (0 = 12 o'clock, clockwise).
    function clockPoint(clockDeg as Numeric, r as Float) as [Float, Float] {
        var a = Math.toRadians(clockDeg);
        return [(r * Math.sin(a)).toFloat(), (-r * Math.cos(a)).toFloat()];
    }

    // Offset [dx, dy] from the centre of the point at radius r on a CIQ
    // angle (0 = 3 o'clock, counter-clockwise).
    function ciqPoint(ciqDeg as Numeric, r as Float) as [Float, Float] {
        var a = Math.toRadians(ciqDeg);
        return [(r * Math.cos(a)).toFloat(), (-r * Math.sin(a)).toFloat()];
    }

    // Left x of each field column for a row centred on centreX. A null width
    // is an empty slot: it gets a null position and the row re-centres.
    function fieldColumns(widths as Array<Float or Null>, gap as Float, centreX as Float) as Array<Float or Null> {
        var total = 0.0f;
        var count = 0;
        for (var i = 0; i < widths.size(); i++) {
            if (widths[i] != null) {
                total += widths[i] as Float;
                count++;
            }
        }
        var lefts = new Array<Float or Null>[widths.size()];
        if (count == 0) {
            return lefts;
        }
        var x = centreX - (total + gap * (count - 1)) / 2;
        for (var i = 0; i < widths.size(); i++) {
            if (widths[i] != null) {
                lefts[i] = x;
                x += (widths[i] as Float) + gap;
            }
        }
        return lefts;
    }

    // Whether [x, y, w, h] contains the point (edges included).
    function boxContains(box as [Number, Number, Number, Number] or Null, x as Numeric, y as Numeric) as Boolean {
        return box != null && x >= box[0] && x <= box[0] + box[2] && y >= box[1] && y <= box[1] + box[3];
    }

    // Whether a tap at design offset (dx, dy) from the centre selects the arc:
    // the rim, or the readout below the fields.
    function inArcZone(dx as Float, dy as Float) as Boolean {
        return dx * dx + dy * dy > ARC_HIT_R * ARC_HIT_R
            || (dy > READOUT_VALUE_Y - C - 18 && dx.abs() < 70);
    }
}
