import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Bearing: a minimalist compass dial. A 60-tick bezel (accent every five minutes, long
// cardinals), a north triangle, a thin time with the minutes in the accent colour, the
// battery above and steps below. Geometry follows design/reference.png scaled to 454 px;
// every coordinate is in design pixels.
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;

    private const INK = 0xF2F4F7;
    private const LABEL = 0xD6DAE0;
    private const MINOR_TICK = 0x4A505A;
    private const DIVIDER = 0x3A3F47;
    private const OUTLINE = 0xC8CDD4;

    // Bezel ticks: outer radius, and the inner radius of minor, five-minute and cardinal ticks
    private const TICK_OUT = 222.0f;
    private const TICK_MINOR = 214.0f;
    private const TICK_MAJOR = 208.0f;
    private const TICK_CARDINAL = 200.0f;
    // Always-On: hour ticks only, kept AOD_SHIFT_MAX inside the rim
    private const AOD_TICK_OUT = 214.0f;
    private const AOD_TICK_IN = 202.0f;

    private const NORTH_Y = 44.0f;
    private const BATTERY_Y = 98.0f;
    private const BATTERY_TEXT_Y = 130.0f;
    private const TIME_Y = 227.0f;
    private const COLON_GAP = 22.0f;
    private const COLON_DY = 18.0f;
    private const DIVIDER_Y = 308.0f;
    private const STEPS_ICON_Y = 341.0f;
    private const STEPS_TEXT_Y = 377.0f;

    private var mFontTime as FontType = Graphics.FONT_NUMBER_HOT;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0x8CC8F0, FaceFormat.DATE_WATCH);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = loadFontSet([Rez.Fonts.Time, Rez.Fonts.Label] as Array<ResourceId>,
            [Graphics.FONT_NUMBER_HOT, Graphics.FONT_XTINY] as Array<FontType>);
        mFontTime = f[0];
        mFontLabel = f[1];
    }

    // ---- Drawing --------------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (alwaysOn()) {
            var shift = aodShift(clock.min);
            var dx = shift[0].toFloat();
            var dy = shift[1].toFloat();
            drawAodTicks(dc, dx, dy);
            drawNorth(dc, dx, dy, FaceKit.mix(mAccent, 0x000000, 0.6f));
            drawTime(dc, now, dx, dy, 0x9AA0A8, FaceKit.mix(mAccent, 0x000000, 0.7f), 0x9AA0A8);
            return;
        }

        drawTicks(dc);
        drawNorth(dc, 0.0f, 0.0f, mAccent);
        drawBattery(dc);
        drawTime(dc, now, 0.0f, 0.0f, INK, mAccent, INK);

        dc.setColor(ink(DIVIDER), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(1.5f, mScale));
        dc.drawLine((C - 23) * mScale, DIVIDER_Y * mScale, (C + 23) * mScale, DIVIDER_Y * mScale);
        dc.setPenWidth(1);

        drawSteps(dc);
    }

    // 60 ticks: minor grey, every fifth in the accent, longer at 12, 3, 6 and 9.
    private function drawTicks(dc as Dc) as Void {
        for (var i = 0; i < 60; i++) {
            var inner = TICK_MINOR;
            var width = 1.5f;
            var color = MINOR_TICK;
            if (i % 15 == 0) {
                inner = TICK_CARDINAL;
                width = 3.0f;
                color = (i % 30 == 0) ? FaceKit.mix(INK, mAccent, 0.5f) : mAccent;
            } else if (i % 5 == 0) {
                inner = TICK_MAJOR;
                width = 2.5f;
                color = mAccent;
            }
            dc.setColor(ink(color), Graphics.COLOR_TRANSPARENT);
            drawTick(dc, i * 6.0f, inner, TICK_OUT, width, 0.0f, 0.0f);
        }
        dc.setPenWidth(1);
    }

    // Always-On: the 12 hour ticks only, dimmed.
    private function drawAodTicks(dc as Dc, dx as Float, dy as Float) as Void {
        dc.setColor(ink(FaceKit.mix(mAccent, 0x000000, 0.45f)), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            drawTick(dc, i * 30.0f, AOD_TICK_IN, AOD_TICK_OUT, 2.0f, dx, dy);
        }
        dc.setPenWidth(1);
    }

    // A radial tick at deg clockwise from 12 o'clock, from radius r0 to r1.
    private function drawTick(dc as Dc, deg as Float, r0 as Float, r1 as Float, width as Float, dx as Float, dy as Float) as Void {
        var a = Math.toRadians(deg);
        var s = Math.sin(a);
        var c = Math.cos(a);
        dc.setPenWidth(FaceKit.penWidth(width, mScale));
        dc.drawLine((C + dx + s * r0) * mScale, (C + dy - c * r0) * mScale,
            (C + dx + s * r1) * mScale, (C + dy - c * r1) * mScale);
    }

    // The north marker under the 12 o'clock tick.
    private function drawNorth(dc as Dc, dx as Float, dy as Float, color as Number) as Void {
        var x = (C + dx) * mScale;
        var top = (NORTH_Y + dy) * mScale;
        var base = (NORTH_Y + 14 + dy) * mScale;
        var half = 8 * mScale;
        dc.setColor(ink(color), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x, top], [x + half, base], [x - half, base]]);
    }

    // Hours right of centre-left, a two-dot colon at the centre, minutes in the accent.
    private function drawTime(dc as Dc, now as Gregorian.Info, dx as Float, dy as Float,
            hourColor as Number, minuteColor as Number, colonColor as Number) as Void {
        var cx = (C + dx) * mScale;
        var y = (TIME_Y + dy) * mScale;
        var justify = Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(ink(hourColor), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - COLON_GAP * mScale, y, mFontTime, FaceKit.hourText(now.hour as Number), Graphics.TEXT_JUSTIFY_RIGHT | justify);
        dc.setColor(ink(minuteColor), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + COLON_GAP * mScale, y, mFontTime, FaceKit.twoDigits(now.min as Number), Graphics.TEXT_JUSTIFY_LEFT | justify);
        dc.setColor(ink(colonColor), Graphics.COLOR_TRANSPARENT);
        var r = 4.5f * mScale;
        dc.fillCircle(cx, y - COLON_DY * mScale, r);
        dc.fillCircle(cx, y + COLON_DY * mScale, r);
    }

    // Battery outline filled to the charge in the accent, the percentage under it.
    private function drawBattery(dc as Dc) as Void {
        var level = batteryLevel();
        var w = 42.0f;
        var h = 18.0f;
        var left = C - w / 2 - 2;
        var top = BATTERY_Y - h / 2;
        dc.setColor(ink(OUTLINE), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(1.5f, mScale));
        dc.drawRoundedRectangle(left * mScale, top * mScale, w * mScale, h * mScale, 3 * mScale);
        dc.setPenWidth(1);
        dc.fillRectangle((left + w + 1) * mScale, (BATTERY_Y - 4) * mScale, 3 * mScale, 8 * mScale);
        var fill = (w - 8) * level / 100.0f;
        if (fill > 0) {
            dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle((left + 4) * mScale, (top + 4) * mScale, fill * mScale, (h - 8) * mScale);
        }
        dc.setColor(ink(LABEL), Graphics.COLOR_TRANSPARENT);
        dc.drawText(C * mScale, BATTERY_TEXT_Y * mScale, mFontLabel, batteryText(level),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Two footprint outlines in the accent and the step count under them.
    private function drawSteps(dc as Dc) as Void {
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(1.5f, mScale));
        drawFoot(dc, C - 8, STEPS_ICON_Y + 3);
        drawFoot(dc, C + 8, STEPS_ICON_Y - 3);
        dc.setPenWidth(1);
        dc.setColor(ink(LABEL), Graphics.COLOR_TRANSPARENT);
        dc.drawText(C * mScale, STEPS_TEXT_Y * mScale, mFontLabel, FaceFormat.thousandsText(mData.steps),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A sole (oval) above a heel (small circle), centred on (x, y) design px.
    private function drawFoot(dc as Dc, x as Float, y as Float) as Void {
        dc.drawEllipse(x * mScale, (y - 4) * mScale, 5.5f * mScale, 8.5f * mScale);
        dc.drawCircle(x * mScale, (y + 10) * mScale, 3.5f * mScale);
    }

    // ---- Values -----------------------------------------------------------------

    // Battery charge in percent, 0..100 (the demo build's sample value there).
    function batteryLevel() as Number {
        var pct = FaceDemo.battery(Math.round(System.getSystemStats().battery).toNumber());
        return pct < 0 ? 0 : (pct > 100 ? 100 : pct);
    }

    // "78%".
    function batteryText(level as Number) as String {
        return level.toString() + "%";
    }
}
