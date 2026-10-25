import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Bearing: a compass-bezel minimal face. A 60-tick ring (long ticks at 12 / 3 / 6 / 9,
// accent ticks every five minutes), a north triangle under 12, ultra-thin time with the
// hours in white and the minutes in the accent, battery above and steps below.
// Geometry follows the design (design/mockup-454.png, measured from design-source.jpg);
// every coordinate is in design pixels (454 x 454) times mScale.
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;

    private const GROUND = 0x0F1315;
    private const WHITE = 0xF8F9FB;
    private const MINOR_TICK = 0x737679;
    private const DIVIDER = 0x7D8085;

    // Time: the colon sits at the centre, the hours end at HOURS_RIGHT and the minutes start
    // at MINUTES_LEFT (the digit fonts are tabular, so the layout doesn't move with the time).
    private const TIME_Y = 227.0f;
    private const HOURS_RIGHT = 202.7f;
    private const MINUTES_LEFT = 241.9f;
    private const COLON_R = 4.05f;
    private const COLON_UP = 17.7f;
    private const COLON_DOWN = 17.4f;

    // Tick ring: [inner, outer] radius and width
    private const MINOR_IN = 202.7f;
    private const MINOR_OUT = 212.5f;
    private const FIVE_IN = 197.9f;
    private const FIVE_OUT = 212.7f;
    private const FIVE_W = 1.8f;
    private const CARDINAL_IN = 193.5f;
    private const CARDINAL_OUT = 216.0f;
    private const CARDINAL_W = 2.7f;

    // North triangle under the 12 o'clock tick
    private const NORTH_TOP = 50.4f;
    private const NORTH_BASE = 63.5f;
    private const NORTH_HALF = 7.85f;

    // Editor data slots (resources/configs/watchface.xml): 1 = above the time (battery by
    // default), 2 = below it (steps by default). Each is an icon (or the field's label) over
    // its reading.
    private const SLOT_TOP = 1;
    private const SLOT_BOTTOM = 2;
    private const TOP_ICON_Y = 101.75f;
    private const TOP_TEXT_Y = 132.4f;
    private const BOTTOM_ICON_Y = 338.25f;
    private const BOTTOM_TEXT_Y = 371.7f;
    private const DIVIDER_Y = 305.3f;
    private const DIVIDER_HALF = 22.25f;
    private const SLOT_BOX_W = 96.0f;
    private const SLOT_BOX_H = 62.0f;

    // The reading fonts' line box runs from the top of % down to the comma's tail, so the
    // digits' centre sits this share of the line height above the box's centre.
    private const READING_RAISE = 0.045f;

    private var mFontTime as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontTop as FontType = Graphics.FONT_XTINY;
    private var mFontBottom as FontType = Graphics.FONT_XTINY;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;
    private var mFontValue as FontType = Graphics.FONT_XTINY;

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0xA8D3F3, FaceFormat.DATE_WATCH);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = loadFontSet([Rez.Fonts.Time, Rez.Fonts.ReadingTop, Rez.Fonts.ReadingBottom, Rez.Fonts.Label,
                Rez.Fonts.Value] as Array<ResourceId>,
            [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_XTINY, Graphics.FONT_XTINY, Graphics.FONT_XTINY,
                Graphics.FONT_XTINY] as Array<FontType>);
        mFontTime = f[0];
        mFontTop = f[1];
        mFontBottom = f[2];
        mFontLabel = f[3];
        mFontValue = f[4];
    }

    // ---- Drawing --------------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var hours = FaceKit.hourText(clock.hour);
        var minutes = FaceKit.twoDigits(clock.min);

        if (alwaysOn()) {
            drawAlwaysOn(dc, clock, hours, minutes);
            return;
        }

        dc.setColor(ink(GROUND), ink(GROUND));
        dc.clear();
        drawTicks(dc, 0.0f, 0.0f, false);
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        drawNorth(dc, 0.0f, 0.0f);
        drawTime(dc, hours, minutes, WHITE, mAccent, 0.0f, 0.0f);

        dc.setColor(ink(DIVIDER), Graphics.COLOR_TRANSPARENT);
        fillBox(dc, C - DIVIDER_HALF, DIVIDER_Y - 0.8f, DIVIDER_HALF * 2, 1.6f);

        // The editor draws the slot it is previewing itself
        if (mEditingSlot != SLOT_TOP) {
            drawSlot(dc, SLOT_TOP);
        }
        if (mEditingSlot != SLOT_BOTTOM) {
            drawSlot(dc, SLOT_BOTTOM);
        }
    }

    // Always-On: the four long ticks, the north mark and the time, dimmed and moved every
    // minute (aodShift); the thin digits keep it far below 10 % lit.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hours as String, minutes as String) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        var dx = shift[0].toFloat();
        var dy = shift[1].toFloat();
        drawTicks(dc, dx, dy, true);
        dc.setColor(FaceKit.mix(mAccent, 0x000000, 0.6f), Graphics.COLOR_TRANSPARENT);
        drawNorth(dc, dx, dy);
        drawTime(dc, hours, minutes, 0xA4A8AD, FaceKit.mix(mAccent, 0x000000, 0.75f), dx, dy);
    }

    // 60 ticks: grey minutes, accent (lightened) five-minute ticks, long ones at 12 / 3 / 6 / 9.
    // Always-On draws only the long ones, dimmed.
    private function drawTicks(dc as Dc, dx as Float, dy as Float, aod as Boolean) as Void {
        var tint = FaceKit.mix(mAccent, 0xFFFFFF, 0.6f);
        for (var i = 0; i < 60; i++) {
            if (i % 15 == 0) {
                dc.setColor(aod ? FaceKit.mix(tint, 0x000000, 0.55f) : ink(tint), Graphics.COLOR_TRANSPARENT);
                tick(dc, i, CARDINAL_IN, CARDINAL_OUT, CARDINAL_W, dx, dy);
            } else if (aod) {
                continue;
            } else if (i % 5 == 0) {
                dc.setColor(ink(tint), Graphics.COLOR_TRANSPARENT);
                tick(dc, i, FIVE_IN, FIVE_OUT, FIVE_W, dx, dy);
            } else {
                dc.setColor(ink(MINOR_TICK), Graphics.COLOR_TRANSPARENT);
                var a = FaceKit.clockPoint(i * 6, MINOR_IN);
                var b = FaceKit.clockPoint(i * 6, MINOR_OUT);
                dc.setPenWidth(1);
                dc.drawLine((C + a[0] + dx) * mScale, (C + a[1] + dy) * mScale, (C + b[0] + dx) * mScale, (C + b[1] + dy) * mScale);
            }
        }
    }

    // A radial bar with square ends, as a polygon (pen widths round to whole pixels).
    private function tick(dc as Dc, minute as Number, r0 as Float, r1 as Float, w as Float, dx as Float, dy as Float) as Void {
        var a = Math.toRadians(minute * 6);
        var sx = Math.sin(a).toFloat();
        var sy = -Math.cos(a).toFloat();
        var hx = -sy * w / 2;
        var hy = sx * w / 2;
        var cx = C + dx;
        var cy = C + dy;
        dc.fillPolygon([
            [(cx + sx * r0 + hx) * mScale, (cy + sy * r0 + hy) * mScale],
            [(cx + sx * r1 + hx) * mScale, (cy + sy * r1 + hy) * mScale],
            [(cx + sx * r1 - hx) * mScale, (cy + sy * r1 - hy) * mScale],
            [(cx + sx * r0 - hx) * mScale, (cy + sy * r0 - hy) * mScale]
        ] as Array<[Float, Float]>);
    }

    // The north triangle, in the current colour.
    private function drawNorth(dc as Dc, dx as Float, dy as Float) as Void {
        dc.fillPolygon([
            [(C + dx) * mScale, (NORTH_TOP + dy) * mScale],
            [(C + NORTH_HALF + dx) * mScale, (NORTH_BASE + dy) * mScale],
            [(C - NORTH_HALF + dx) * mScale, (NORTH_BASE + dy) * mScale]
        ] as Array<[Float, Float]>);
    }

    // Hours right of centre-minus-gap, a two-dot colon at the centre, minutes after it.
    private function drawTime(dc as Dc, hours as String, minutes as String, hourColor as Number, minuteColor as Number,
            dx as Float, dy as Float) as Void {
        var y = (TIME_Y + dy) * mScale;
        dc.setColor(ink(hourColor), Graphics.COLOR_TRANSPARENT);
        dc.drawText((HOURS_RIGHT + dx) * mScale, y, mFontTime, hours, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.fillCircle((C + dx) * mScale, (TIME_Y - COLON_UP + dy) * mScale, COLON_R * mScale);
        dc.fillCircle((C + dx) * mScale, (TIME_Y + COLON_DOWN + dy) * mScale, COLON_R * mScale);
        dc.setColor(ink(minuteColor), Graphics.COLOR_TRANSPARENT);
        dc.drawText((MINUTES_LEFT + dx) * mScale, y, mFontTime, minutes, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- Data slots (on-watch editor) --------------------------------------------
    // Battery and steps are the face's own icon-over-reading; any other field shows its
    // label (in the accent) over its value. A slot set to battery or steps shows that one,
    // whichever slot it is.

    function slots() as Array<Number> {
        return [SLOT_TOP, SLOT_BOTTOM] as Array<Number>;
    }

    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        if (slot == SLOT_TOP) {
            return box(C - SLOT_BOX_W / 2, (TOP_ICON_Y + TOP_TEXT_Y) / 2 - SLOT_BOX_H / 2, SLOT_BOX_W, SLOT_BOX_H);
        }
        if (slot == SLOT_BOTTOM) {
            return box(C - SLOT_BOX_W / 2, (BOTTOM_ICON_Y + BOTTOM_TEXT_Y) / 2 - SLOT_BOX_H / 2, SLOT_BOX_W, SLOT_BOX_H);
        }
        return null;
    }

    function drawSlot(dc as Dc, slot as Number) as Void {
        var top = slot == SLOT_TOP;
        if (!top && slot != SLOT_BOTTOM) {
            return;
        }
        var iconY = top ? TOP_ICON_Y : BOTTOM_ICON_Y;
        var textY = top ? TOP_TEXT_Y : BOTTOM_TEXT_Y;
        var font = top ? mFontTop : mFontBottom;
        var type = shownType(slot);
        if (type == Complications.COMPLICATION_TYPE_BATTERY) {
            drawBattery(dc, iconY, battery());
            drawReading(dc, textY, font, battery().toString() + "%");
        } else if (type == Complications.COMPLICATION_TYPE_STEPS) {
            drawSteps(dc, iconY);
            var steps = mData.steps;
            drawReading(dc, textY, font, steps != null ? FaceKit.thousands(steps) : FaceFormat.NO_VALUE);
        } else {
            var t = slotText(slot);
            dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
            var label = (t != null && t[1].length() > 0) ? t[1] : "";
            dc.drawText(C * mScale, iconY * mScale, mFontLabel, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(ink(WHITE), Graphics.COLOR_TRANSPARENT);
            dc.drawText(C * mScale, textY * mScale, mFontValue, t != null ? t[0] : FaceFormat.NO_VALUE,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // The field a slot shows: the picked one, or the slot's own (battery / steps) without one.
    function shownType(slot as Number) as Number {
        var type = slotType(slot);
        if (type != null) {
            return type;
        }
        return slot == SLOT_TOP ? Complications.COMPLICATION_TYPE_BATTERY : Complications.COMPLICATION_TYPE_STEPS;
    }

    // A reading in the face's own digits, centred on y.
    private function drawReading(dc as Dc, y as Float, font as FontType, text as String) as Void {
        dc.setColor(ink(WHITE), Graphics.COLOR_TRANSPARENT);
        var raise = dc.getFontHeight(font) * READING_RAISE;
        dc.drawText(C * mScale, y * mScale - raise, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Battery outline (white) with the charge filled in the accent, centred on y.
    private function drawBattery(dc as Dc, y as Float, level as Number) as Void {
        var x0 = 206.6f;
        var w = 41.3f;
        var h = 19.5f;
        var top = y - h / 2;
        var line = 1.6f;
        dc.setColor(ink(WHITE), Graphics.COLOR_TRANSPARENT);
        fillRound(dc, x0, top, w, h, 2.6f);
        dc.setColor(ink(GROUND), Graphics.COLOR_TRANSPARENT);
        fillRound(dc, x0 + line, top + line, w - 2 * line, h - 2 * line, 1.2f);
        dc.setColor(ink(WHITE), Graphics.COLOR_TRANSPARENT);
        fillRound(dc, x0 + w + 0.5f, y - 4.45f, 2.1f, 8.9f, 0.8f);
        var full = w - 2 * 3.7f;
        var fill = full * (level < 0 ? 0 : (level > 100 ? 100 : level)) / 100.0f;
        if (fill >= 0.5f) {
            dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
            fillBox(dc, x0 + 3.7f, y - 6.05f, fill, 12.1f);
        }
    }

    // Two footprint outlines (sole and heel each), the right one higher, centred on y.
    private function drawSteps(dc as Dc, y as Float) as Void {
        var o = y - 338.25f;
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(1.3f, mScale));
        outline(dc, sole(220.95f, 337.45f + o, 4.45f, 7.15f));
        outline(dc, heel(218.1f, 224.9f, 345.6f + o, 352.0f + o));
        outline(dc, sole(233.8f, 332.45f + o, 4.7f, 7.95f));
        outline(dc, heel(229.6f, 236.4f, 341.4f + o, 347.8f + o));
        dc.setPenWidth(1);
    }

    // Sole: an egg, wider at the toe (top), as screen points.
    private function sole(cx as Float, cy as Float, a as Float, b as Float) as Array<[Float, Float]> {
        var pts = new Array<[Float, Float]>[20];
        for (var i = 0; i < 20; i++) {
            var t = 2 * Math.PI * i / 20;
            var s = Math.sin(t);
            var x = cx + a * Math.cos(t) * (1 + 0.12f * s);
            pts[i] = [x.toFloat() * mScale, (cy - b * s).toFloat() * mScale];
        }
        return pts;
    }

    // Heel: flat top, rounded bottom.
    private function heel(x0 as Float, x1 as Float, top as Float, bottom as Float) as Array<[Float, Float]> {
        var cx = (x0 + x1) / 2;
        var a = (x1 - x0) / 2;
        var cy = top + (bottom - top) * 0.3f;
        var b = bottom - cy;
        var pts = new Array<[Float, Float]>[12];
        pts[0] = [x1 * mScale, top * mScale];
        pts[1] = [x0 * mScale, top * mScale];
        for (var i = 0; i < 10; i++) {
            var t = Math.PI * i / 9;
            pts[i + 2] = [(cx - a * Math.cos(t)).toFloat() * mScale, (cy + b * Math.sin(t)).toFloat() * mScale];
        }
        return pts;
    }

    private function outline(dc as Dc, pts as Array<[Float, Float]>) as Void {
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var a = pts[i];
            var b = pts[(i + 1) % n];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
    }

    // Watch battery 0..100 (fixed in demo builds).
    private function battery() as Number {
        return FaceDemo.battery(Math.round(System.getSystemStats().battery).toNumber());
    }

    private function fillBox(dc as Dc, x as Float, y as Float, w as Float, h as Float) as Void {
        var b = box(x, y, w, h);
        dc.fillRectangle(b[0], b[1], b[2] > 0 ? b[2] : 1, b[3] > 0 ? b[3] : 1);
    }

    private function fillRound(dc as Dc, x as Float, y as Float, w as Float, h as Float, r as Float) as Void {
        var b = box(x, y, w, h);
        var rr = r * mScale;
        dc.fillRoundedRectangle(b[0], b[1], b[2] > 0 ? b[2] : 1, b[3] > 0 ? b[3] : 1, rr < 1 ? 1 : rr);
    }

    // [x, y, w, h] in px of a box in design px.
    private function box(x as Float, y as Float, w as Float, h as Float) as [Number, Number, Number, Number] {
        var x0 = Math.round(x * mScale).toNumber();
        var y0 = Math.round(y * mScale).toNumber();
        return [x0, y0, Math.round((x + w) * mScale).toNumber() - x0, Math.round((y + h) * mScale).toNumber() - y0];
    }
}
