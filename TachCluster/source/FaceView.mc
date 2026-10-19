import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Tach Cluster: a rev counter whose needle shows the hour (0-12, the last two hours in the
// red zone); the ticks light up to the needle. The gear indicator is the weekday (P on
// Sunday, 1-6 Monday to Saturday), the LCD shows the time and steps as ODO, the fuel bar is
// the watch battery and the temperature bar the heart rate. Geometry follows the canvas
// mockup (Tach.dc.html, 454 px).
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;
    private const TICK_OUT = 211.0f;
    private const NUM_R = 166.0f;
    private const GEARS = ["P", "1", "2", "3", "4", "5", "6"] as Array<String>;
    // Data slots (design px): 1 = the LCD's ODO line, 2 = the caption above the hub; boxes [x, y, w, h]
    private const ODO_Y = 315.0f;
    private const CAPTION_Y = 148.0f;
    private const SLOT_BOXES = [[188, 303, 130, 24], [147, 142, 160, 22]] as Array<Array<Number>>;

    private var mFontNum as FontType = Graphics.FONT_SMALL;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;
    private var mFontGear as FontType = Graphics.FONT_MEDIUM;
    private var mFontLcd as FontType = Graphics.FONT_SMALL;
    private var mFontMono as FontType = Graphics.FONT_XTINY;
    private var mFontBar as FontType = Graphics.FONT_XTINY;

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0xFF6A13, FaceFormat.DATE_NAMED);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = loadFontSet([Rez.Fonts.Num, Rez.Fonts.Label, Rez.Fonts.Gear, Rez.Fonts.Lcd, Rez.Fonts.Mono, Rez.Fonts.Bar] as Array<ResourceId>,
            [Graphics.FONT_SMALL, Graphics.FONT_XTINY, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_XTINY, Graphics.FONT_XTINY] as Array<FontType>);
        mFontNum = f[0];
        mFontLabel = f[1];
        mFontGear = f[2];
        mFontLcd = f[3];
        mFontMono = f[4];
        mFontBar = f[5];
    }

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var value = (clock.hour % 12) + (clock.min + clock.sec / 60.0f) / 60.0f;
        var hm = FaceKit.hourText(clock.hour) + ":" + FaceKit.twoDigits(clock.min);

        if (alwaysOn()) {
            drawAlwaysOn(dc, clock, value, hm);
            return;
        }
        dc.setColor(ink(ShopKit.GROUND), ShopKit.GROUND);
        dc.clear();

        // Ticks every quarter hour, lit up to the needle; 10-12 is the red zone
        for (var i = 0; i <= 48; i++) {
            var v = i / 4.0f;
            var major = i % 4 == 0;
            var on = v <= value;
            var color = v >= 10 ? (on ? ShopKit.RED : 0x5A2222) : (on ? ShopKit.TEXT : 0x2E3034);
            dc.setColor(ink(color), Graphics.COLOR_TRANSPARENT);
            ShopKit.bar(dc, angle(v), TICK_OUT - (major ? 24 : 12), TICK_OUT, major ? 4 : 3, mScale);
        }
        for (var n = 0; n <= 12; n++) {
            var p = FaceKit.clockPoint(angle(n), NUM_R);
            dc.setColor(ink(n >= 10 ? ShopKit.RED : ShopKit.SOFT), Graphics.COLOR_TRANSPARENT);
            dc.drawText((C + p[0]) * mScale, (C + p[1]) * mScale, mFontNum, n.toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        if (mEditingSlot != 2) {
            drawSlot(dc, 2);
        }

        drawNeedle(dc, angle(value));
        drawLcd(dc, now, hm);
        drawBars(dc);
    }

    // ---- Data slots: 1 = the ODO line in the LCD, 2 = the dial caption ----

    function slots() as Array<Number> {
        return [1, 2] as Array<Number>;
    }

    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        if (slot < 1 || slot > 2) {
            return null;
        }
        var b = SLOT_BOXES[slot - 1];
        return [(b[0] * mScale).toNumber(), (b[1] * mScale).toNumber(), (b[2] * mScale).toNumber(),
            (b[3] * mScale).toNumber()] as [Number, Number, Number, Number];
    }

    // The system field picked in the editor ("LABEL value"), or the face's own text without one.
    // Text wider than the slot drops its letter-spacing, then falls back to a smaller system font.
    function drawSlot(dc as Dc, slot as Number) as Void {
        var text = slotText(slot);
        if (text == null) {
            text = ownReadout(slot);
        }
        var w = (SLOT_BOXES[slot - 1][2] - 2) * mScale;
        dc.setColor(ink(ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
        if (slot == 1) {
            var line = text[1] + " " + text[0];
            var mono = dc.getTextWidthInPixels(line, mFontMono) > w ? Graphics.FONT_XTINY : mFontMono;
            dc.drawText(253 * mScale, ODO_Y * mScale, mono, line, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var caption = text[1] + " · " + text[0];
        var font = mFontLabel;
        var tracking = fitTracking(dc, font, caption, 3 * mScale, w);
        if (FaceKit.trackedWidth(dc, font, caption, tracking) > w) {
            font = Graphics.FONT_XTINY;
        }
        FaceKit.drawTracked(dc, C * mScale, CAPTION_Y * mScale, font, caption, tracking, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // [value, LABEL] of the face's own text in a slot: steps as ODO, and the dial's unit.
    function ownReadout(slot as Number) as [String, String] {
        if (slot == 1) {
            var steps = mData.steps;
            return [steps != null ? steps.format("%06d") : "------", "ODO"];
        }
        return ["r/min", "×1 HOUR"];
    }

    // Clock angle of a dial value 0..12 (a 270 degree sweep, open at the bottom).
    private function angle(v as Numeric) as Float {
        return -135.0f + v * 22.5f;
    }

    private function drawNeedle(dc as Dc, deg as Float) as Void {
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        ShopKit.bar(dc, deg, -24, 179, 6, mScale);
        var tip = ShopKit.polar(deg, 179, 0, C, C, mScale);
        dc.fillCircle(tip[0], tip[1], 3 * mScale);
        dc.setColor(ink(0x1C1D1F), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(C * mScale, C * mScale, 22 * mScale);
        dc.setColor(ink(ShopKit.DARK_STEEL), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
        dc.drawCircle(C * mScale, C * mScale, 20.5f * mScale);
        dc.setPenWidth(1);
    }

    // The LCD under the hub: gear (weekday) | time over ODO (steps).
    private function drawLcd(dc as Dc, now as Gregorian.Info, hm as String) as Void {
        dc.setColor(ink(ShopKit.DIM), Graphics.COLOR_TRANSPARENT);
        ShopKit.box(dc, 132, 268, 190, 62, 8, mScale);
        dc.setColor(ink(0x101112), Graphics.COLOR_TRANSPARENT);
        ShopKit.box(dc, 134, 270, 186, 58, 6, mScale);
        dc.setColor(ink(ShopKit.DIM), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(184 * mScale, 270 * mScale, FaceKit.penWidth(2.0f, mScale), 58 * mScale);

        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        dc.drawText(159 * mScale, 290 * mScale, mFontGear, GEARS[((now.day_of_week as Number) + 6) % 7],
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(ink(ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, 159 * mScale, 316 * mScale, mFontBar, "GEAR", 2 * mScale, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(ink(ShopKit.TEXT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(253 * mScale, 290 * mScale, mFontLcd, hm, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (mEditingSlot != 1) {
            drawSlot(dc, 1);
        }
    }

    // Fuel = watch battery (E..F), temperature = heart rate (C..H), eight segments each.
    private function drawBars(dc as Dc) as Void {
        var fuel = Math.round(ShopKit.battery() / 100.0f * 8).toNumber();
        var hr = mData.heartRate();
        var temp = hr != null ? Math.round((hr - 30) / 120.0f * 8).toNumber() : 0;
        temp = temp < 0 ? 0 : (temp > 8 ? 8 : temp);
        gaugeRow(dc, 349.0f, "BATT", "E", "F", fuel, ShopKit.TEXT);
        gaugeRow(dc, 368.0f, "HR " + ShopKit.orDash(hr), "C", "H", temp, temp >= 7 ? ShopKit.RED : mAccent);
    }

    private function gaugeRow(dc as Dc, y as Float, label as String, low as String, high as String,
            lit as Number, color as Number) as Void {
        // Mockup positions (label at 142, E / C centred at 186, F / H at 304, the eight
        // segments 195-295), with the low mark and segments pushed right where the label is
        // wider (small screens, where the text is relatively larger)
        var mid = Graphics.TEXT_JUSTIFY_VCENTER;
        var wLow = dc.getTextWidthInPixels(low, mFontBar) / 2.0f;
        var wHigh = dc.getTextWidthInPixels(high, mFontBar) / 2.0f;
        var lowX = 186 * mScale;
        var space = 3 * mScale < 3 ? 3.0f : 3 * mScale;
        var labelEnd = 142 * mScale + dc.getTextWidthInPixels(label, mFontBar) + space + wLow;
        lowX = labelEnd > lowX ? labelEnd : lowX;
        var highX = 304 * mScale;
        dc.setColor(ink(ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
        dc.drawText(142 * mScale, y * mScale, mFontBar, label, Graphics.TEXT_JUSTIFY_LEFT | mid);
        dc.drawText(lowX, y * mScale, mFontBar, low, Graphics.TEXT_JUSTIFY_CENTER | mid);
        dc.drawText(highX, y * mScale, mFontBar, high, Graphics.TEXT_JUSTIFY_CENTER | mid);
        var left = 195 * mScale + (lowX - 186 * mScale);
        var right = 295 * mScale;
        if (right > highX - wHigh - mScale) {
            right = highX - wHigh - mScale;
        }
        var gap = 3 * mScale;
        var w = (right - left - 7 * gap) / 8;
        for (var i = 0; i < 8; i++) {
            dc.setColor(ink(i < lit ? color : ShopKit.DIM), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(left + i * (w + gap), (y - 5) * mScale, w, 10 * mScale, 2 * mScale);
        }
    }

    // Always-On: the hour ticks dim, a thin needle and the LCD time.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, value as Float, hm as String) as Void {
        dc.setColor(ink(Graphics.COLOR_BLACK), Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        var cx = C + shift[0];
        var cy = C + shift[1];
        for (var n = 0; n <= 12; n++) {
            dc.setColor(ink(n >= 10 ? 0x5A2222 : ShopKit.STEEL), Graphics.COLOR_TRANSPARENT);
            var a = ShopKit.polar(angle(n), TICK_OUT - 16, 0, cx, cy, mScale);
            var b = ShopKit.polar(angle(n), TICK_OUT, 0, cx, cy, mScale);
            dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
        var tip = ShopKit.polar(angle(value), 170, 0, cx, cy, mScale);
        var tail = ShopKit.polar(angle(value), 24, 0, cx, cy, mScale);
        dc.setColor(FaceKit.mix(mAccent, 0x000000, 0.7f), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tail[0], tail[1], tip[0], tip[1]);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        dc.drawCircle(cx * mScale, cy * mScale, 20 * mScale);
        dc.setPenWidth(1);
        dc.setColor(ink(ShopKit.AOD_TEXT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx * mScale, (cy + 72) * mScale, mFontLcd, hm, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
