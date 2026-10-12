import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

// Per-watch tests: they check the layout on the screen of the watch they run on, so
// running the suite on one product per screen type and API version
// (tools\run-device-tests.ps1) covers every supported watch.

(:test)
function deviceLogsItsConfiguration(logger as Logger) as Boolean {
    var s = System.getDeviceSettings();
    var p = ApexTestUtil.probe();
    logger.debug("screen " + s.screenWidth + "x" + s.screenHeight + ", " + (p[:amoled] ? "AMOLED" : "MIP")
        + ", firmware API " + s.monkeyVersion + ", custom fonts " + p[:customFonts]
        + ", editor " + (Application has :WatchFaceConfig) + ", vector fonts " + (Graphics has :getVectorFont));
    Test.assertEqual(s.screenShape, System.SCREEN_SHAPE_ROUND);
    Test.assertEqual(s.screenWidth, s.screenHeight);
    return true;
}

// Each screen size has its own bitmap fonts (resources-round-<W>x<W>); they must load.
(:test)
function bitmapFontsLoadOnThisWatch(logger as Logger) as Boolean {
    Test.assertMessage(ApexTestUtil.probe()[:customFonts] as Boolean, "bitmap fonts did not load; system fonts in use");
    return true;
}

// Font heights follow the screen: the time is ~0.7 of its 176 px design size scaled
// (cap height), the small text at least its legibility minimum.
(:test)
function fontSizesMatchThisScreen(logger as Logger) as Boolean {
    var p = ApexTestUtil.probe();
    var s = p[:scale] as Float;
    var hours = p[:hHours] as Number;
    logger.debug("time " + hours + " px, value " + p[:hValue] + ", label " + p[:hLabel] + ", date " + p[:hDate]);
    Test.assertMessage(hours >= 176 * s * 0.6f && hours <= 176 * s * 0.8f, "time height " + hours + " for scale " + s);
    var labelSize = 18 * s > 10 ? 18 * s : 10;
    var label = p[:hLabel] as Number;
    Test.assertMessage(label >= labelSize * 0.5f && label <= labelSize * 1.1f, "label height " + label);
    var valueSize = 34 * s > 16 ? 34 * s : 16;
    var value = p[:hValue] as Number;
    Test.assertMessage(value >= valueSize * 0.6f && value <= valueSize * 1.1f, "value height " + value);
    Test.assertMessage(value > label, "values must be larger than labels");
    return true;
}

// Top to bottom: date, time, separator, field labels, field values, arc readout value,
// its label, screen edge. No row may overlap the next.
(:test)
function textRowsDoNotOverlapOnThisScreen(logger as Logger) as Boolean {
    var p = ApexTestUtil.probe();
    var rows = [
        ["date", p[:dateY], p[:hDate]],
        ["time", p[:timeY], p[:hHours]],
        ["separator", p[:sepY], 1],
        ["labels", p[:labelY], p[:hLabel]],
        ["values", p[:valueY], p[:hValue]],
        ["readout", p[:readoutValueY], p[:hReadoutValue]],
        ["readout label", p[:readoutLabelY], p[:hReadoutLabel]]
    ];
    for (var i = 0; i + 1 < rows.size(); i++) {
        var a = rows[i] as Array;
        var b = rows[i + 1] as Array;
        var bottom = (a[1] as Numeric) + (a[2] as Numeric) / 2.0f;
        var top = (b[1] as Numeric) - (b[2] as Numeric) / 2.0f;
        Test.assertMessage(bottom <= top + 1, (a[0] as String) + " (bottom " + bottom + ") overlaps " + (b[0] as String) + " (top " + top + ")");
    }
    var last = rows[rows.size() - 1] as Array;
    Test.assert((last[1] as Numeric) + (last[2] as Numeric) / 2.0f < ApexTestUtil.screen());
    return true;
}

// Half the width (px) of the circle of radius r at a distance dy from the centre.
function halfChord(r as Float, dy as Float) as Float {
    return Math.sqrt(r * r - dy * dy).toFloat();
}

// The time's box (widest hours, both weights; minutes) stays inside the arc at its top
// corners, where the arc closes in, with and without the colon. The box includes
// the digits' side bearings, so 1 px of it may touch the arc's inner edge.
(:test)
function timeFitsInsideTheArcOnThisScreen(logger as Logger) as Boolean {
    for (var colon = 0; colon < 2; colon++) {
        var p = ApexTestUtil.probeColon(colon == 1);
        ApexTestUtil.assertEqual(p[:colon], colon == 1);
        var c = ApexTestUtil.screen() / 2.0f;
        var top = (p[:timeY] as Float) - (p[:hHours] as Number) / 2.0f;
        var hc = halfChord(p[:arcInner] as Float, top - c) + 1;
        var hoursWide = (p[:wHours] as Number) > (p[:wHoursAod] as Number) ? p[:wHours] as Number : p[:wHoursAod] as Number;
        var left = (p[:hoursRight] as Float) - hoursWide;
        var right = (p[:minutesLeft] as Float) + (p[:wMinutes] as Number);
        var what = colon == 1 ? " (colon)" : "";
        logger.debug("time" + what + " " + left + " .. " + right + ", arc " + (c - hc) + " .. " + (c + hc));
        Test.assertMessage(left > c - hc, "hours" + what + " start at " + left + ", arc at " + (c - hc));
        Test.assertMessage(right < c + hc, "minutes" + what + " end at " + right + ", arc at " + (c + hc));
        if (colon == 1) {
            // the colon's ink (about half its advance) fits between hours and minutes
            var w = p[:wColon] as Number;
            Test.assertMessage(w * 0.6f <= (p[:minutesLeft] as Float) - (p[:hoursRight] as Float), "colon " + w + " px too wide");
        }
    }
    return true;
}

// The date (widest form, 14 characters) stays inside the arc at its top corners.
(:test)
function dateFitsInsideTheArcOnThisScreen(logger as Logger) as Boolean {
    var p = ApexTestUtil.probe();
    var c = ApexTestUtil.screen() / 2.0f;
    var top = (p[:dateY] as Float) - (p[:hDate] as Number) / 2.0f;
    var hc = halfChord(p[:arcInner] as Float, top - c);
    var w = p[:wDate] as Float;
    logger.debug("date " + w + " px, room " + (2 * hc));
    Test.assertMessage(w / 2 < hc, "date " + w + " px wide, arc leaves " + (2 * hc));
    return true;
}

// The longest arc label (INTENSITY MIN) stays clear of the ticks around 6 o'clock:
// no tick's inner end (minor r 216, major r 213) falls inside its box.
(:test)
function readoutLabelClearsTheTicksOnThisScreen(logger as Logger) as Boolean {
    var p = ApexTestUtil.probe();
    var s = p[:scale] as Float;
    var c = ApexTestUtil.screen() / 2.0f;
    var bottom = (p[:readoutLabelY] as Float) + (p[:hReadoutLabel] as Number) / 2.0f - c;
    var half = (p[:wReadoutLabel] as Float) / 2;
    for (var deg = 120; deg <= 240; deg += 6) {
        var r = (deg % 30 == 0 ? 213 : 216) * s;
        var tick = ApexLayout.clockPoint(deg, r);
        Test.assertMessage(tick[0].abs() > half + 1 || tick[1] > bottom + 0.5f,
            "tick at " + deg + " (" + tick[0] + ", " + tick[1] + ") inside the readout label (half width " + half + ", bottom " + bottom + ")");
    }
    return true;
}

// Every data field box lies inside the arc.
(:test)
function fieldRowFitsInsideTheArcOnThisScreen(logger as Logger) as Boolean {
    var view = new ApexFaceView(true);   // editor mode: all three slots shown
    view.loadPhoneSettings();
    var dc = ApexTestUtil.render(view);
    var p = view.testProbe(dc);
    var c = ApexTestUtil.screen() / 2.0f;
    var r = p[:arcInner] as Float;
    for (var slot = 1; slot <= 3; slot++) {
        var box = view.slotBox(slot) as [Number, Number, Number, Number];
        var corners = [[box[0], box[1]], [box[0] + box[2], box[1]], [box[0], box[1] + box[3]], [box[0] + box[2], box[1] + box[3]]];
        for (var k = 0; k < corners.size(); k++) {
            var dx = (corners[k][0] as Number) - c;
            var dy = (corners[k][1] as Number) - c;
            Test.assertMessage(dx * dx + dy * dy < r * r, "field " + slot + " corner outside the arc");
        }
    }
    return true;
}

// AMOLED: design greys, Always-On instead of low-power seconds. MIP: palette-safe
// greys and seconds through partial updates.
(:test)
function screenTypeDrivesPaletteAndLowPower(logger as Logger) as Boolean {
    var p = ApexTestUtil.probe();
    var settings = System.getDeviceSettings();
    var amoled = (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
    ApexTestUtil.assertEqual(p[:amoled], amoled);
    ApexTestUtil.assertEqual(p[:partialSeconds], !amoled);
    ApexTestUtil.assertEqual(p[:minor], amoled ? 0x34342F : 0x555555);
    ApexTestUtil.assertEqual(p[:rule], amoled ? 0x2A2A28 : 0x555555);
    return true;
}

// The partial-update box at every second stays on this screen and small.
(:test)
function partialUpdateBoxesFitThisScreen(logger as Logger) as Boolean {
    var w = ApexTestUtil.screen();
    var s = w / 454.0f;
    for (var sec = 0; sec < 60; sec++) {
        var box = ApexLayout.cometBox(sec, s);
        Test.assert(box[0] >= -4 && box[1] >= -4 && box[0] + box[2] <= w + 4 && box[1] + box[3] <= w + 4);
        Test.assertMessage(box[2] * box[3] <= 32 * 32 * s * s + 64, "box at " + sec + " is " + box[2] + "x" + box[3]);
    }
    return true;
}

// Always-On, Night mode, low power and the editor all draw on this screen.
(:test)
function everyModeDrawsOnThisScreen(logger as Logger) as Boolean {
    var saved = ApexTestUtil.saveProperties(["NightMode"]);
    try {
        for (var night = 0; night <= 2; night += 2) {
            Application.Properties.setValue("NightMode", night);
            var view = new ApexFaceView(false);
            view.loadPhoneSettings();
            var dc = ApexTestUtil.render(view);
            view.onEnterSleep();
            view.onUpdate(dc);
            view.onPartialUpdate(dc);
            view.onExitSleep();
            view.onUpdate(dc);
            ApexTestUtil.assertEqual(view.testProbe(dc)[:night], night == 2);
        }
        var editor = new ApexFaceView(true);
        var edc = ApexTestUtil.render(editor);
        for (var slot = 1; slot <= ApexEditor.SLOT_ARC; slot++) {
            editor.drawSlot(edc, slot);
        }
    } finally {
        ApexTestUtil.restoreProperties(saved);
    }
    return true;
}
