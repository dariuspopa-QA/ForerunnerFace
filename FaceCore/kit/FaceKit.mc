import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Helpers shared by every face built on FaceCore (one copy, FaceCore/source). Geometry is in
// design pixels of the 454 x 454 canvas; views multiply by width / 454.
module FaceKit {

    const DESIGN = 454.0f;
    const C = 227.0f;

    // [dx, dy] of a clock angle (0 = 12 o'clock, clockwise) at radius r.
    function clockPoint(deg as Numeric, r as Numeric) as [Float, Float] {
        var a = Math.toRadians(deg);
        return [(r * Math.sin(a)).toFloat(), (-r * Math.cos(a)).toFloat()];
    }

    // Connect IQ arc degrees (0 = 3 o'clock, counter-clockwise) of a clock angle.
    function ciqDeg(clockDeg as Numeric) as Float {
        return (90.0f - clockDeg).toFloat();
    }

    // ---- Text: the device-aware layer over FaceFormat (pure, tested) ------

    function twoDigits(n as Number) as String {
        return FaceFormat.twoDigits(n);
    }

    // Hours as the watch is set: zero-padded 24 h, or 12 h without padding.
    function hourText(hour as Number) as String {
        return FaceFormat.hourText(hour, !(System.getDeviceSettings().is24Hour || FaceDemo.FORCE_24H));
    }

    // Gregorian FORMAT_SHORT: day_of_week 1 = Sunday, month 1 = January.
    function dayName(dayOfWeek as Number) as String {
        return FaceFormat.DAYS[(dayOfWeek + 6) % 7] as String;
    }

    function monthName(month as Number) as String {
        return FaceFormat.MONTHS[(month + 11) % 12] as String;
    }

    // The date format to draw for the DateFormat setting (FaceFormat.DATE_*); "watch"
    // follows the distance units (miles: month first).
    function dateFormat(setting as Number) as Number {
        return FaceFormat.dateFormat(setting, System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE);
    }

    // The date after the weekday in a resolved format: "28 SEP" (day unpadded),
    // "28-09-2026" or "09-28-2026" (day and month padded).
    function dateRest(day as Number, month as Number, year as Number, format as Number) as String {
        var text = FaceFormat.dateText(1, day, month, year, format);
        return text.substring(4, text.length()) as String;
    }

    // "MON 28 SEP" / "MON 28-09-2026" / "MON 09-28-2026" for a Gregorian FORMAT_SHORT date.
    function dateText(now as Gregorian.Info, format as Number) as String {
        return FaceFormat.dateText(now.day_of_week as Number, now.day as Number, now.month as Number,
            now.year as Number, format);
    }

    // Like dateText, with the weekday and month names in the watch's language
    // (Gregorian FORMAT_MEDIUM), for faces drawn with system fonts.
    function localDateText(setting as Number) as String {
        var m = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var weekday = (m.day_of_week as String).toUpper() + " ";
        var format = dateFormat(setting);
        if (format != FaceFormat.DATE_NAMED) {
            var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            return weekday + dateRest(d.day as Number, d.month as Number, d.year as Number, format);
        }
        return weekday + (m.day as Number).format("%d") + " " + (m.month as String).toUpper();
    }

    function clamp01(f as Float) as Float {
        return f < 0.0f ? 0.0f : (f > 1.0f ? 1.0f : f);
    }

    // Colour a laid over b at weight w (0..1), as one opaque colour.
    function mix(a as Number, b as Number, w as Float) as Number {
        var r = ((a >> 16) & 0xFF) * w + ((b >> 16) & 0xFF) * (1.0f - w);
        var g = ((a >> 8) & 0xFF) * w + ((b >> 8) & 0xFF) * (1.0f - w);
        var bl = (a & 0xFF) * w + (b & 0xFF) * (1.0f - w);
        return (Math.round(r).toNumber() << 16) | (Math.round(g).toNumber() << 8) | Math.round(bl).toNumber();
    }

    function thousands(n as Number) as String {
        return FaceFormat.thousands(n);
    }

    // "2h 12m" / "45m" for a number of minutes.
    function durationText(minutes as Number) as String {
        if (minutes < 60) {
            return minutes.toString() + "m";
        }
        return (minutes / 60).toString() + "h " + (minutes % 60).toString() + "m";
    }

    // "18:20" (24 h) or "6:20" (12 h) for an hour of the day as a float.
    function clockText(hours as Float) as String {
        var total = Math.round(hours * 60).toNumber() % 1440;
        return hourText(total / 60) + ":" + twoDigits(total % 60);
    }

    function prop(key as String, fallback as Number) as Number {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
        } catch (e) {
            value = null;
        }
        if (value instanceof Boolean) {
            return value ? 1 : 0;
        }
        return (value instanceof Number) ? value : fallback;
    }

    function burnInProtection() as Boolean {
        var settings = System.getDeviceSettings();
        return (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
    }

    // ---- Always-On drift (from ApexFace) ---------------------------------

    // No pixel may stay lit for more than 3 minutes, so every 4 consecutive minutes must
    // move the Always-On drawing more than a stroke width both across and down (>= 14
    // design px; checked by FaceKitTest). The eight positions were searched for ApexFace
    // (offline render of minutes 00-59) to keep changing minute digits from lining up.
    const AOD_SHIFTS = [[-5, -10], [9, -10], [-10, 3], [9, 10], [-6, -6], [8, -10], [-10, 3], [9, 10]];
    // Largest offset in AOD_SHIFTS: keep Always-On drawing this far inside the rim
    const AOD_SHIFT_MAX = 10;
    const AOD_MIN_SPAN = 14;

    // [dx, dy] in design px for the minute of the hour.
    function aodShift(minute as Number) as Array<Number> {
        return AOD_SHIFTS[minute % AOD_SHIFTS.size()] as Array<Number>;
    }

    // Smallest horizontal and vertical spread [dx, dy] of a shift pattern over any
    // window of consecutive minutes: a stroke thinner than this can't stay lit
    // for the whole window.
    function minShiftSpan(shifts as Array, window as Number) as [Number, Number] {
        var minX = 1000;
        var minY = 1000;
        var n = shifts.size();
        for (var start = 0; start < n; start++) {
            var loX = 1000; var hiX = -1000; var loY = 1000; var hiY = -1000;
            for (var k = 0; k < window; k++) {
                var s = shifts[(start + k) % n] as Array<Number>;
                if (s[0] < loX) { loX = s[0]; }
                if (s[0] > hiX) { hiX = s[0]; }
                if (s[1] < loY) { loY = s[1]; }
                if (s[1] > hiY) { hiY = s[1]; }
            }
            if (hiX - loX < minX) { minX = hiX - loX; }
            if (hiY - loY < minY) { minY = hiY - loY; }
        }
        return [minX, minY];
    }

    // ---- Fonts (from ApexFace) -------------------------------------------

    // On Connect IQ 4+ loadResource returns fonts as references into the shared
    // graphics pool, and the watch may purge the resource behind a reference while
    // the face holds nothing stronger. Drawing with a reference it then can't bring
    // back is a fatal Invalid Value that try/catch can't stop (ApexFace on the fr970,
    // 11 Oct 2026). So faces keep the resource itself.
    function strongResource(id as ResourceId) as Object or Null {
        var resource = WatchUi.loadResource(id);
        if (resource instanceof Graphics.ResourceReference) {
            return resource.get();
        }
        return resource;
    }

    // Each font in ids held strongly, or the system font at the same index when it
    // can't be loaded.
    function loadFonts(ids as Array<ResourceId>, fallbacks as Array<FontType>) as Array<FontType> {
        var fonts = new Array<FontType>[ids.size()];
        for (var i = 0; i < ids.size(); i++) {
            var font = null;
            try {
                font = strongResource(ids[i]);
            } catch (e) {
                font = null;
            }
            fonts[i] = font != null ? font as FontResource : fallbacks[i];
        }
        return fonts;
    }

    function penWidth(w as Float, scale as Float) as Number {
        var p = Math.round(w * scale).toNumber();
        return p < 1 ? 1 : p;
    }

    // Arc along the clock (0 = 12 o'clock) from fromDeg clockwise to toDeg, with round
    // caps, in px around (cx, cy). Pen width w px.
    function roundArc(dc as Dc, cx as Float, cy as Float, r as Float, fromDeg as Float, toDeg as Float, w as Number) as Void {
        var span = toDeg - fromDeg;
        while (span < 0) {
            span += 360.0f;
        }
        if (span < 0.5f) {
            return;
        }
        if (span > 359.5f) {
            span = 359.5f;
        }
        dc.setPenWidth(w);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, ciqDeg(fromDeg), ciqDeg(fromDeg + span));
        var a = clockPoint(fromDeg, r);
        var b = clockPoint(fromDeg + span, r);
        dc.fillCircle(cx + a[0], cy + a[1], w / 2.0f);
        dc.fillCircle(cx + b[0], cy + b[1], w / 2.0f);
    }

    // drawText has no letter-spacing, so tracked text is drawn glyph by glyph. x is the
    // left edge, centre or right edge (by justify: TEXT_JUSTIFY_LEFT / CENTER / RIGHT).
    function drawTracked(dc as Dc, x as Float, y as Float, font as FontType, text as String,
            tracking as Float, justify as Number) as Void {
        var chars = text.toCharArray();
        if (chars.size() == 0) {
            return;
        }
        var left = x;
        if (justify == Graphics.TEXT_JUSTIFY_CENTER) {
            left = x - trackedWidth(dc, font, text, tracking) / 2;
        } else if (justify == Graphics.TEXT_JUSTIFY_RIGHT) {
            left = x - trackedWidth(dc, font, text, tracking);
        }
        for (var i = 0; i < chars.size(); i++) {
            var ch = chars[i].toString();
            dc.drawText(left, y, font, ch, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            left += dc.getTextWidthInPixels(ch, font) + tracking;
        }
    }

    function trackedWidth(dc as Dc, font as FontType, text as String, tracking as Float) as Float {
        var chars = text.toCharArray();
        if (chars.size() == 0) {
            return 0.0f;
        }
        var width = tracking * (chars.size() - 1);
        for (var i = 0; i < chars.size(); i++) {
            width += dc.getTextWidthInPixels(chars[i].toString(), font);
        }
        return width;
    }
}
