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
    const READOUT_VALUE_Y = 389.0f;

    // Taps outside this radius select the arc (the rim)
    const ARC_HIT_R = 170.0f;

    // Always-On: content moves through these design-pixel offsets, one step per
    // minute, so no pixel stays lit in the same place (AMOLED burn-in).
    const AOD_SHIFTS = [[0, 0], [3, 1], [-1, 3], [-3, -1], [1, -3], [2, 2], [-2, 2], [0, -2]];

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

    // Centre y (px) of a text row under another: its design position, pushed
    // down when the real font heights would make the two rows overlap.
    function rowBelow(aboveY as Float, designY as Float, aboveHeight as Numeric, height as Numeric) as Float {
        var minY = (aboveY + (aboveHeight + height) * 0.425f).toFloat();
        return designY > minY ? designY : minY;
    }

    // Centre y (px) of a text row over another: its design position, pulled up
    // when the real font heights would make the two rows overlap.
    function rowAbove(belowY as Float, designY as Float, belowHeight as Numeric, height as Numeric) as Float {
        var maxY = (belowY - (belowHeight + height) * 0.425f).toFloat();
        return designY < maxY ? designY : maxY;
    }

    // Burn-in offset [x, y] for the given minute.
    function aodShift(minute as Number) as Array<Number> {
        return AOD_SHIFTS[minute % AOD_SHIFTS.size()] as Array<Number>;
    }

    // CIQ end angle of the seconds trail, drawn clockwise from 12 o'clock (CIQ 90).
    function trailEnd(sec as Number) as Number {
        return 90 - sec * 6;
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
