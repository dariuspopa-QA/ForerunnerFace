import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.StringUtil;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// OBD Scanner: a one-colour diagnostic tester screen. Time with seconds, a table of live
// "PIDs" (heart rate, steps, battery as volts, stress; each row a data slot of the on-watch
// editor), the day's heart rate as a bar
// graph and a fault code: real ones for a low battery or high stress, else a rotating
// shop joke. Geometry follows the canvas mockup (Scanner.dc.html, 454 px).
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;
    private const GROUND = 0x0B0802;
    private const ROWS_Y = [215, 242, 269, 296] as Array<Number>;
    // Data slot type each PID row draws itself (its editor default, watchface.xml)
    private const OWN_TYPES = [Complications.COMPLICATION_TYPE_HEART_RATE, Complications.COMPLICATION_TYPE_STEPS,
        Complications.COMPLICATION_TYPE_BATTERY, Complications.COMPLICATION_TYPE_STRESS] as Array<Number>;
    // Engine outline of the check-engine lamp, 26 x 18 icon px
    private const ENGINE = [[4, 6], [7, 6], [7, 3], [15, 3], [15, 6], [18, 6], [20, 9], [23, 9], [23, 7], [25, 7],
        [25, 14], [23, 14], [23, 12], [20, 12], [18, 16], [7, 16], [4, 13], [2, 13], [2, 8], [4, 8]];
    private const JOKES = [["P1010", "10MM SOCKET NOT FOUND", "NO 10MM SOCKET"],
        ["P0420", "COFFEE BELOW THRESHOLD", "LOW COFFEE"], ["U0100", "LOST COMM WITH CUSTOMER", "CUSTOMER NO COMM"],
        ["B1200", "LUNCH BREAK OVERDUE", "LUNCH OVERDUE"]];

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
        var f = loadFontSet([Rez.Fonts.Head, Rez.Fonts.Time, Rez.Fonts.Date, Rez.Fonts.Row, Rez.Fonts.Small, Rez.Fonts.Code] as Array<ResourceId>,
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
        dc.setColor(ink(GROUND), GROUND);
        dc.clear();
        var dim = FaceKit.mix(mAccent, GROUND, 0.27f);
        var faded = FaceKit.mix(mAccent, GROUND, 0.6f);
        var mid = Graphics.TEXT_JUSTIFY_VCENTER;

        drawHeader(dc, 0, 0, mAccent);
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        // HH:MM:SS awake; HH:MM while a MIP watch sleeps (it redraws once a minute)
        dc.drawText(C * mScale, 108 * mScale, mFontTime, showSeconds() ? hm + ":" + FaceKit.twoDigits(clock.sec) : hm,
            Graphics.TEXT_JUSTIFY_CENTER | mid);
        dc.setColor(ink(faded), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 158 * mScale, mFontDate, FaceKit.dateText(now, FaceKit.dateFormat(mDateSetting)),
            3 * mScale, Graphics.TEXT_JUSTIFY_CENTER);

        // PID table
        dc.setColor(ink(dim), Graphics.COLOR_TRANSPARENT);
        var lines = [182, 202, 229, 256, 283, 310] as Array<Number>;
        for (var i = 0; i < lines.size(); i++) {
            dc.fillRectangle(87 * mScale, lines[i] * mScale, 280 * mScale, FaceKit.penWidth(1.0f, mScale));
        }
        dc.setColor(ink(faded), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, 87 * mScale, 192 * mScale, mFontSmall, "PID", 2 * mScale, Graphics.TEXT_JUSTIFY_LEFT);
        FaceKit.drawTracked(dc, 367 * mScale, 192 * mScale, mFontSmall, "VALUE", 2 * mScale, Graphics.TEXT_JUSTIFY_RIGHT);
        var ids = slots();
        for (var i = 0; i < ids.size(); i++) {
            if (ids[i] != mEditingSlot) {
                drawSlot(dc, ids[i]);
            }
        }

        drawHeartGraph(dc);

        // Fault code box
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        ShopKit.box(dc, 104, 360, 246, 50, 6, mScale);
        dc.setColor(ink(GROUND), Graphics.COLOR_TRANSPARENT);
        ShopKit.box(dc, 106, 362, 242, 46, 4, mScale);
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 377 * mScale, mFontCode, "DTC " + code[0], 2 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        // The short text where the long one doesn't fit the box (small screens, where the
        // text is relatively larger than in the mockup)
        var text = code[1];
        if (FaceKit.trackedWidth(dc, mFontSmall, text, 1 * mScale) > 232 * mScale) {
            text = code[2];
        }
        dc.setColor(FaceKit.mix(mAccent, GROUND, 0.75f), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 397 * mScale, mFontSmall, text, 1 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Data slots: the four PID rows. Each shows the face's own reading until another
    // data field is picked for it in the on-watch editor.

    function slots() as Array<Number> {
        return [1, 2, 3, 4] as Array<Number>;
    }

    // The row between its two table lines, across the table's full width.
    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        if (slot < 1 || slot > ROWS_Y.size()) {
            return null;
        }
        var top = Math.round((ROWS_Y[slot - 1] - 13) * mScale).toNumber();
        var bottom = Math.round((ROWS_Y[slot - 1] + 14) * mScale).toNumber();
        return [Math.round(87 * mScale).toNumber(), top, Math.round(280 * mScale).toNumber(), bottom - top];
    }

    function drawSlot(dc as Dc, slot as Number) as Void {
        var row = slotRow(slot);
        var valueWidth = dc.getTextWidthInPixels(row[1], mFontRow);
        var label = row[0];
        // A long field name gives way to the value: cut to what fits
        while (label.length() > 1 && dc.getTextWidthInPixels(label, mFontRow) + 12 * mScale + valueWidth > 280 * mScale) {
            label = label.substring(0, label.length() - 1) as String;
        }
        var y = ROWS_Y[slot - 1] * mScale;
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        dc.drawText(87 * mScale, y, mFontRow, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(367 * mScale, y, mFontRow, row[1], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // [PID name, value] of a row: the face's own reading while the row holds its own type
    // (the editor default) or nothing, else the picked field's.
    function slotRow(slot as Number) as [String, String] {
        var type = slotType(slot);
        var picked = type != null && type != OWN_TYPES[slot - 1] ? slotText(slot) : null;
        if (picked != null) {
            return [pidName(picked[1]), picked[0]];
        }
        if (slot == 1) {
            var hr = mData.heartRate();
            return ["HEART.RATE", hr != null ? hr.format("%03d") + " bpm" : "--- bpm"];
        }
        if (slot == 2) {
            var steps = mData.steps;
            return ["STEP.COUNT", steps != null ? steps.format("%05d") : "-----"];
        }
        if (slot == 3) {
            return ["BATT.VOLT", ShopKit.volts(ShopKit.battery()) + " V"];
        }
        var stress = mData.stress;
        return ["STRESS.LOAD", (stress != null ? stress.toString() : "--") + " %"];
    }

    // A field label as a PID name: "body battery" -> "BODY.BATTERY", none -> "PID".
    static function pidName(label as String) as String {
        if (label.length() == 0) {
            return "PID";
        }
        var chars = label.toUpper().toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (chars[i] == ' ') {
                chars[i] = '.';
            }
        }
        return StringUtil.charArrayToString(chars);
    }

    // Real codes first (P0562 system voltage low, P0217 over temperature), else a joke
    // that changes every five seconds while awake.
    private function faultCode(clock as System.ClockTime, batt as Number) as Array<String> {
        if (batt < 15) {
            return ["P0562", "SYSTEM VOLTAGE LOW", "VOLTAGE LOW"];
        }
        var stress = mData.stress;
        if (stress != null && stress > 75) {
            return ["P0217", "OVERTEMP - HIGH STRESS", "HIGH STRESS"];
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
        dc.setColor(ink(color), Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 24 && i < hours.size(); i++) {
            var v = hours[i];
            var h = v != null ? 2 + (v - lo) / span * 24 : 2.0f;
            dc.fillRectangle((107 + i * (w + 3)) * mScale, (352 - h) * mScale, w * mScale, h * mScale);
        }
    }

    // Always-On: lamp, thin dim time, fault code.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hm as String, code as Array<String>) as Void {
        dc.setColor(ink(Graphics.COLOR_BLACK), Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        var color = FaceKit.mix(mAccent, 0x000000, 0.6f);
        drawHeader(dc, shift[0], 60 + shift[1], color);
        dc.setColor(ink(color), Graphics.COLOR_TRANSPARENT);
        dc.drawText((C + shift[0]) * mScale, (C + shift[1]) * mScale, mFontTime, hm,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        FaceKit.drawTracked(dc, (C + shift[0]) * mScale, (300 + shift[1]) * mScale, mFontCode, "DTC " + code[0],
            2 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
