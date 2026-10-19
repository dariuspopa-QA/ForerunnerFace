import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Socket Set: the hour markers are socket ends, 8 to 19 mm (hour + 7). The current hour's
// socket is lit; the 10 mm one is missing, as always. A 72-tooth ratchet ring fills with
// the minutes. Time, date, heart rate, battery (as a car battery's volts) and steps (ODO)
// in the middle. Geometry follows the canvas mockup (Main.dc.html, 454 px).
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;
    private const SOCKET_R = 166.0f;
    private const MISSING = 10;
    private const TIME_TOP = 140.0f;
    // Data slots: centres of the three readouts, and each slot's box (design px)
    private const SLOT_X = [152.0f, 227.0f, 302.0f];
    private const SLOT_W = 74.0f;
    private const SLOT_TOP = 238.0f;
    private const SLOT_H = 50.0f;

    private var mFontTime as FontType = Graphics.FONT_NUMBER_HOT;
    private var mFontTimeAod as FontType = Graphics.FONT_NUMBER_HOT;
    private var mFontSec as FontType = Graphics.FONT_SMALL;
    private var mFontSocket as FontType = Graphics.FONT_XTINY;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;
    private var mFontValue as FontType = Graphics.FONT_SMALL;

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0xFF6A13, FaceFormat.DATE_NAMED);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = loadFontSet([Rez.Fonts.Time, Rez.Fonts.TimeAod, Rez.Fonts.Sec, Rez.Fonts.Socket, Rez.Fonts.Date, Rez.Fonts.Label, Rez.Fonts.Value] as Array<ResourceId>,
            [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_SMALL, Graphics.FONT_XTINY, Graphics.FONT_XTINY, Graphics.FONT_XTINY, Graphics.FONT_SMALL] as Array<FontType>);
        mFontTime = f[0];
        mFontTimeAod = f[1];
        mFontSec = f[2];
        mFontSocket = f[3];
        mFontDate = f[4];
        mFontLabel = f[5];
        mFontValue = f[6];
    }

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var hour12 = clock.hour % 12 == 0 ? 12 : clock.hour % 12;
        var hm = FaceKit.hourText(clock.hour) + ":" + FaceKit.twoDigits(clock.min);

        dc.setColor(ink(ShopKit.GROUND), ShopKit.GROUND);
        dc.clear();
        if (alwaysOn()) {
            drawAlwaysOn(dc, clock, hour12, hm);
            return;
        }

        // Ratchet ring: 72 teeth lit with the minutes (and seconds while awake)
        var progress = clock.min + clock.sec / 60.0f;
        var lit = Math.floor(progress / 60.0f * 72).toNumber();
        for (var i = 0; i < 72; i++) {
            dc.setColor(ink(i < lit ? mAccent : ShopKit.DIM), Graphics.COLOR_TRANSPARENT);
            tooth(dc, i * 5);
        }
        for (var h = 1; h <= 12; h++) {
            drawSocket(dc, h, h == hour12);
        }

        dc.setColor(ink(ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 116 * mScale, mFontDate,
            FaceKit.dateText(now, FaceKit.dateFormat(mDateSetting)), 4 * mScale, Graphics.TEXT_JUSTIFY_CENTER);

        // HH:MM with the seconds hung top right, the pair centred (no seconds while a MIP
        // watch sleeps: it redraws once a minute)
        var sec = FaceKit.twoDigits(clock.sec);
        var gap = 3 * mScale;
        var wT = dc.getTextWidthInPixels(hm, mFontTime);
        var wS = dc.getTextWidthInPixels(sec, mFontSec);
        var left = C * mScale - (wT + gap + wS) / 2;
        dc.setColor(ink(ShopKit.TEXT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, TIME_TOP * mScale, mFontTime, hm, Graphics.TEXT_JUSTIFY_LEFT);
        if (showSeconds()) {
            dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + wT + gap, (TIME_TOP + 2) * mScale, mFontSec, sec, Graphics.TEXT_JUSTIFY_LEFT);
        }

        dc.setColor(ink(ShopKit.DIM), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(127 * mScale, 222 * mScale, 200 * mScale, FaceKit.penWidth(2.0f, mScale));

        for (var slot = 1; slot <= 3; slot++) {
            if (slot != mEditingSlot) {
                drawSlot(dc, slot);
            }
        }
    }

    // ---- Data slots: the three readouts under the time (1 = HR, 2 = BATT, 3 = ODO) ----

    function slots() as Array<Number> {
        return [1, 2, 3] as Array<Number>;
    }

    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        if (slot < 1 || slot > 3) {
            return null;
        }
        var x = (SLOT_X[slot - 1] - SLOT_W / 2) * mScale;
        return [x.toNumber(), (SLOT_TOP * mScale).toNumber(), (SLOT_W * mScale).toNumber(),
            (SLOT_H * mScale).toNumber()] as [Number, Number, Number, Number];
    }

    // The system field picked in the editor, or the face's own reading without one.
    function drawSlot(dc as Dc, slot as Number) as Void {
        var text = slotText(slot);
        if (text == null) {
            text = ownReadout(slot);
        }
        readout(dc, SLOT_X[slot - 1], text[1], text[0]);
    }

    // [value, LABEL] of the face's own reading in a slot.
    function ownReadout(slot as Number) as [String, String] {
        if (slot == 1) {
            return [ShopKit.orDash(mData.heartRate()), "HR"];
        }
        if (slot == 2) {
            return [ShopKit.volts(ShopKit.battery()) + "V", "BATT"];
        }
        var steps = mData.steps;
        return [steps != null ? FaceKit.thousands(steps) : "--", "ODO"];
    }

    // One sawtooth of the ratchet ring: the leading edge long, the trailing edge cut back.
    private function tooth(dc as Dc, deg as Number) as Void {
        dc.fillPolygon([
            ShopKit.polar(deg, 209, -3, C, C, mScale), ShopKit.polar(deg, 224, -3, C, C, mScale),
            ShopKit.polar(deg, 219, 3, C, C, mScale), ShopKit.polar(deg, 209, 3, C, C, mScale)]);
    }

    private function drawSocket(dc as Dc, hour as Number, lit as Boolean) as Void {
        var size = hour + 7;
        var p = FaceKit.clockPoint(hour * 30, SOCKET_R);
        var dx = C + p[0];
        var dy = C + p[1];
        var cx = dx * mScale;
        var cy = dy * mScale;
        if (size == MISSING) {
            dc.setColor(ink(0x4A4E53), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
            for (var a = 0; a < 360; a += 30) {
                dc.drawArc(cx, cy, 26 * mScale, Graphics.ARC_CLOCKWISE, FaceKit.ciqDeg(a), FaceKit.ciqDeg(a + 16));
            }
            dc.setPenWidth(1);
            dc.setColor(ink(0x6B7178), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, mFontSocket, size.toString() + "?", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        dc.setColor(ink(lit ? mAccent : ShopKit.STEEL), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 27 * mScale);
        dc.setColor(ink(lit ? mAccent : 0x141516), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 24 * mScale);
        dc.setColor(ink(lit ? ShopKit.GROUND : ShopKit.DARK_STEEL), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        ShopKit.outline(dc, ShopKit.hexagon(dx, dy, 17, mScale));
        dc.setPenWidth(1);
        dc.setColor(ink(lit ? ShopKit.GROUND : ShopKit.SOFT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, mFontSocket, size.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A label over a value, centred on x. Text wider than the slot (a long system field) drops
    // its letter-spacing, then falls back to a smaller system font.
    private function readout(dc as Dc, x as Float, label as String, value as String) as Void {
        var w = (SLOT_W - 2) * mScale;
        dc.setColor(ink(ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
        var labelFont = mFontLabel;
        var tracking = fitTracking(dc, labelFont, label, 2 * mScale, w);
        if (FaceKit.trackedWidth(dc, labelFont, label, tracking) > w) {
            labelFont = Graphics.FONT_XTINY;
        }
        FaceKit.drawTracked(dc, x * mScale, 244 * mScale, labelFont, label, tracking, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(ink(ShopKit.TEXT), Graphics.COLOR_TRANSPARENT);
        var valueFont = mFontValue;
        if (dc.getTextWidthInPixels(value, valueFont) > w) {
            valueFont = Graphics.FONT_XTINY;
        }
        dc.drawText(x * mScale, 270 * mScale, valueFont, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Always-On: socket outlines (the current hour's in the accent) and thin digits.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hour12 as Number, hm as String) as Void {
        dc.setColor(ink(Graphics.COLOR_BLACK), Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        for (var h = 1; h <= 12; h++) {
            if (h + 7 == MISSING) {
                continue;
            }
            var p = FaceKit.clockPoint(h * 30, SOCKET_R);
            dc.setColor(ink(h == hour12 ? mAccent : ShopKit.DARK_STEEL), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle((C + p[0] + shift[0]) * mScale, (C + p[1] + shift[1]) * mScale, 26 * mScale);
        }
        dc.setPenWidth(1);
        dc.setColor(ink(ShopKit.AOD_TEXT), Graphics.COLOR_TRANSPARENT);
        dc.drawText((C + shift[0]) * mScale, (TIME_TOP + shift[1]) * mScale, mFontTimeAod, hm, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
