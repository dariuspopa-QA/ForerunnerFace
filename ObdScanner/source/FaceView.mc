import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// OBD Scanner: a one-colour diagnostic tester screen. Time with seconds, a table of live
// "PIDs" (heart rate, steps, battery as volts, stress), the day's heart rate as a bar
// graph and a fault code: real ones for a low battery or high stress, else a rotating
// shop joke. Geometry follows the canvas mockup (Scanner.dc.html, 454 px).
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;
    private const GROUND = 0x0B0802;
    private const ROWS_Y = [215, 242, 269, 296] as Array<Number>;
    // Engine outline of the check-engine lamp, 26 x 18 icon px
    private const ENGINE = [[4, 6], [7, 6], [7, 3], [15, 3], [15, 6], [18, 6], [20, 9], [23, 9], [23, 7], [25, 7],
        [25, 14], [23, 14], [23, 12], [20, 12], [18, 16], [7, 16], [4, 13], [2, 13], [2, 8], [4, 8]];
    private const JOKES = [["P1010", "10MM SOCKET NOT FOUND"], ["P0420", "COFFEE BELOW THRESHOLD"],
        ["U0100", "LOST COMM WITH CUSTOMER"], ["B1200", "LUNCH BREAK OVERDUE"]];

    private var mFontHead as FontType = Graphics.FONT_XTINY;
    private var mFontTime as FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontRow as FontType = Graphics.FONT_TINY;
    private var mFontSmall as FontType = Graphics.FONT_XTINY;
    private var mFontCode as FontType = Graphics.FONT_TINY;

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0xFFB000, FaceFormat.DATE_NAMED);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = FaceKit.loadFonts([Rez.Fonts.Head, Rez.Fonts.Time, Rez.Fonts.Date, Rez.Fonts.Row, Rez.Fonts.Small, Rez.Fonts.Code] as Array<ResourceId>,
            [Graphics.FONT_XTINY, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_XTINY, Graphics.FONT_TINY] as Array<FontType>);
        mFontHead = f[0];
        mFontTime = f[1];
        mFontDate = f[2];
        mFontRow = f[3];
        mFontSmall = f[4];
        mFontCode = f[5];
    }

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var hm = FaceKit.hourText(clock.hour) + ":" + FaceKit.twoDigits(clock.min);
        var batt = ShopKit.battery();
        var code = faultCode(clock, batt);

        if (alwaysOn()) {
            drawAlwaysOn(dc, clock, hm, code);
            return;
        }
        dc.setColor(GROUND, GROUND);
        dc.clear();
        var dim = FaceKit.mix(mAccent, GROUND, 0.27f);
        var faded = FaceKit.mix(mAccent, GROUND, 0.6f);
        var mid = Graphics.TEXT_JUSTIFY_VCENTER;

        drawHeader(dc, 0, 0, mAccent);
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(C * mScale, 108 * mScale, mFontTime, hm + ":" + FaceKit.twoDigits(clock.sec),
            Graphics.TEXT_JUSTIFY_CENTER | mid);
        dc.setColor(faded, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 158 * mScale, mFontDate, FaceKit.dateText(now, FaceKit.dateFormat(mDateSetting)),
            3 * mScale, Graphics.TEXT_JUSTIFY_CENTER);

        // PID table
        dc.setColor(dim, Graphics.COLOR_TRANSPARENT);
        var lines = [182, 202, 229, 256, 283, 310] as Array<Number>;
        for (var i = 0; i < lines.size(); i++) {
            dc.fillRectangle(87 * mScale, lines[i] * mScale, 280 * mScale, FaceKit.penWidth(1.0f, mScale));
        }
        dc.setColor(faded, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, 87 * mScale, 192 * mScale, mFontSmall, "PID", 2 * mScale, Graphics.TEXT_JUSTIFY_LEFT);
        FaceKit.drawTracked(dc, 367 * mScale, 192 * mScale, mFontSmall, "VALUE", 2 * mScale, Graphics.TEXT_JUSTIFY_RIGHT);
        var hr = mData.heartRate();
        var steps = mData.steps;
        var stress = mData.stress;
        var rows = [
            ["HEART.RATE", hr != null ? hr.format("%03d") + " bpm" : "--- bpm"],
            ["STEP.COUNT", steps != null ? steps.format("%05d") : "-----"],
            ["BATT.VOLT", ShopKit.volts(batt) + " V"],
            ["STRESS.LOAD", (stress != null ? stress.toString() : "--") + " %"]];
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < rows.size(); i++) {
            var row = rows[i] as Array<String>;
            dc.drawText(87 * mScale, ROWS_Y[i] * mScale, mFontRow, row[0], Graphics.TEXT_JUSTIFY_LEFT | mid);
            dc.drawText(367 * mScale, ROWS_Y[i] * mScale, mFontRow, row[1], Graphics.TEXT_JUSTIFY_RIGHT | mid);
        }

        drawHeartGraph(dc);

        // Fault code box
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        ShopKit.box(dc, 104, 360, 246, 50, 6, mScale);
        dc.setColor(GROUND, Graphics.COLOR_TRANSPARENT);
        ShopKit.box(dc, 106, 362, 242, 46, 4, mScale);
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 377 * mScale, mFontCode, "DTC " + code[0], 2 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(FaceKit.mix(mAccent, GROUND, 0.75f), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 397 * mScale, mFontSmall, code[1], 1 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Real codes first (P0562 system voltage low, P0217 over temperature), else a joke
    // that changes every five seconds while awake.
    private function faultCode(clock as System.ClockTime, batt as Number) as Array<String> {
        if (batt < 15) {
            return ["P0562", "SYSTEM VOLTAGE LOW"];
        }
        var stress = mData.stress;
        if (stress != null && stress > 75) {
            return ["P0217", "OVERTEMP - HIGH STRESS"];
        }
        return JOKES[(clock.min * 12 + clock.sec / 5) % JOKES.size()] as Array<String>;
    }

    // Check-engine lamp + "OBD-II · LIVE", centred at the top.
    private function drawHeader(dc as Dc, dx as Number, dy as Number, color as Number) as Void {
        var label = "OBD-II · LIVE";
        var track = 2 * mScale;
        var wText = FaceKit.trackedWidth(dc, mFontHead, label, track);
        var wAll = 26 * mScale + 8 * mScale + wText;
        var left = (C + dx) * mScale - wAll / 2;
        var top = (45 + dy) * mScale;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        var n = ENGINE.size();
        for (var i = 0; i < n; i++) {
            var a = ENGINE[i] as Array<Number>;
            var b = ENGINE[(i + 1) % n] as Array<Number>;
            dc.drawLine(left + a[0] * mScale, top + a[1] * mScale, left + b[0] * mScale, top + b[1] * mScale);
        }
        dc.setPenWidth(1);
        FaceKit.drawTracked(dc, left + 34 * mScale, top + 9 * mScale, mFontHead, label, track, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Highest heart rate of each of the last 24 hours, scaled between the day's low and high.
    private function drawHeartGraph(dc as Dc) as Void {
        var hours = mData.hrHours();
        var lo = 999;
        var hi = 0;
        for (var i = 0; i < hours.size(); i++) {
            var v = hours[i];
            if (v != null) {
                lo = v < lo ? v : lo;
                hi = v > hi ? v : hi;
            }
        }
        var span = hi > lo ? (hi - lo).toFloat() : 1.0f;
        var w = (240.0f - 23 * 3) / 24;
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 24 && i < hours.size(); i++) {
            var v = hours[i];
            var h = v != null ? 2 + (v - lo) / span * 24 : 2.0f;
            dc.fillRectangle((107 + i * (w + 3)) * mScale, (352 - h) * mScale, w * mScale, h * mScale);
        }
    }

    // Always-On: lamp, thin dim time, fault code.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hm as String, code as Array<String>) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        var color = FaceKit.mix(mAccent, 0x000000, 0.6f);
        drawHeader(dc, shift[0], 60 + shift[1], color);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText((C + shift[0]) * mScale, (C + shift[1]) * mScale, mFontTime, hm,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        FaceKit.drawTracked(dc, (C + shift[0]) * mScale, (300 + shift[1]) * mScale, mFontCode, "DTC " + code[0],
            2 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
