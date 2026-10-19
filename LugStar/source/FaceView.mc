import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Lug Star: the hands are wrenches over a five-lug wheel hub. The nuts are numbered in
// star tightening order (1-3-5-2-4 around the hub); each fifth of the step goal torques
// the next one and draws its line of the star. Geometry follows the canvas mockup
// (Wrench.dc.html, 454 px).
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;
    private const GROUND = 0x0A0A0B;
    private const HUB = 0x17181A;
    private const LUG_R = 112.0f;
    // Tightening order: the lug (clockwise from 12 o'clock) torqued at each step
    private const STAR = [0, 2, 4, 1, 3] as Array<Number>;
    private const COUNT_Y = 386.0f;

    // Editor data slot (resources/configs/watchface.xml) and its tap box (design px): the
    // count line's reading after "3 / 5" (steps by default)
    private const SLOT_COUNT = 1;
    private const SLOT_BOX_W = 280.0f;
    private const SLOT_BOX_H = 40.0f;

    private var mFontSeq as FontType = Graphics.FONT_SMALL;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;
    private var mFontCount as FontType = Graphics.FONT_SMALL;

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0xFFD400, FaceFormat.DATE_NAMED);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = loadFontSet([Rez.Fonts.Seq, Rez.Fonts.Date, Rez.Fonts.Label, Rez.Fonts.Count] as Array<ResourceId>,
            [Graphics.FONT_SMALL, Graphics.FONT_XTINY, Graphics.FONT_XTINY, Graphics.FONT_SMALL] as Array<FontType>);
        mFontSeq = f[0];
        mFontDate = f[1];
        mFontLabel = f[2];
        mFontCount = f[3];
    }

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var hourDeg = ((clock.hour % 12) + clock.min / 60.0f) * 30;
        var minDeg = (clock.min + clock.sec / 60.0f) * 6;
        var steps = mData.steps;
        var goal = mData.stepGoal;
        var frac = FaceData.fraction(steps, goal != null ? goal : 10000);
        var done = frac != null ? Math.floor(frac * 5).toNumber() : 0;

        if (alwaysOn()) {
            drawAlwaysOn(dc, clock, hourDeg, done);
            return;
        }
        dc.setColor(ink(GROUND), GROUND);
        dc.clear();

        dc.setColor(ink(0x1F2124), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        dc.drawCircle(C * mScale, C * mScale, 189 * mScale);
        dc.setPenWidth(1);
        for (var i = 0; i < 60; i++) {
            var major = i % 5 == 0;
            dc.setColor(ink(major ? ShopKit.SOFT : ShopKit.DARK_STEEL), Graphics.COLOR_TRANSPARENT);
            ShopKit.bar(dc, i * 6, major ? 201 : 211, 219, major ? 4 : 2, mScale);
        }

        // The star: a solid line between two torqued nuts, dashed ahead
        dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
        for (var k = 0; k < 5; k++) {
            var a = lug(STAR[k]);
            var b = lug(STAR[(k + 1) % 5]);
            // Segment k joins the (k + 1)th and (k + 2)th nut; the last one closes the star at 5 / 5
            if (k + 1 < done || done >= 5) {
                dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
                dc.drawLine(a[0], a[1], b[0], b[1]);
            } else {
                dc.setColor(ink(0x2C2E31), Graphics.COLOR_TRANSPARENT);
                ShopKit.dashed(dc, a[0], a[1], b[0], b[1], 6 * mScale, 6 * mScale);
            }
        }
        for (var i = 0; i < 5; i++) {
            drawNut(dc, i, STAR.indexOf(i) + 1, done);
        }

        dc.setColor(ink(ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 71 * mScale, mFontDate, FaceKit.dateText(now, FaceKit.dateFormat(mDateSetting)),
            4 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        FaceKit.drawTracked(dc, C * mScale, 363 * mScale, mFontLabel, "TORQUE SEQUENCE", 3 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        // The count line is the editor's data slot; the editor draws it while previewing it.
        if (mEditingSlot != SLOT_COUNT) {
            drawCount(dc, done);
        }

        dc.setColor(ink(HUB), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(C * mScale, C * mScale, 35 * mScale);
        dc.setColor(ink(0x2C2E31), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
        dc.drawCircle(C * mScale, C * mScale, 33.5f * mScale);
        dc.setPenWidth(1);

        drawWrench(dc, hourDeg, 113, 15, 5, 102, 13, 6, ShopKit.SOFT);
        drawWrench(dc, minDeg, 170, 13, 4, 160, 11, 5, ShopKit.TEXT);
        // Second hand while awake (a sleeping MIP watch redraws once a minute)
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        if (showSeconds()) {
            ShopKit.bar(dc, clock.sec * 6, -30, 197, 2, mScale);
        }
        dc.fillCircle(C * mScale, C * mScale, 6 * mScale);
    }

    // "3 / 5 · 7,412 STEPS" (the mockup), or the picked field after the count.
    private function drawCount(dc as Dc, done as Number) as Void {
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        dc.drawText(C * mScale, COUNT_Y * mScale, mFontCount, done + " / 5 · " + countReading(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Nuts torqued so far (0..5): a fifth of the step goal each.
    private function doneNuts() as Number {
        var goal = mData.stepGoal;
        var frac = FaceData.fraction(mData.steps, goal != null ? goal : 10000);
        return frac != null ? Math.floor(frac * 5).toNumber() : 0;
    }

    // ---- Data slot (on-watch editor) ---------------------------------------------
    // 1 = the reading on the count line. Steps (the default) is the face's own "7,412
    // STEPS"; any other field shows as "VALUE LABEL" the same way. The nuts and the star
    // follow the step goal whatever the slot shows.

    function slots() as Array<Number> {
        return [SLOT_COUNT] as Array<Number>;
    }

    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        if (slot != SLOT_COUNT) {
            return null;
        }
        return [((C - SLOT_BOX_W / 2) * mScale).toNumber(), ((COUNT_Y - SLOT_BOX_H / 2) * mScale).toNumber(),
            (SLOT_BOX_W * mScale).toNumber(), (SLOT_BOX_H * mScale).toNumber()];
    }

    function drawSlot(dc as Dc, slot as Number) as Void {
        if (slot == SLOT_COUNT) {
            drawCount(dc, doneNuts());
        }
    }

    // The reading after the count: steps while the slot holds steps or nothing, else the
    // picked field as "VALUE LABEL" ("--" until it has a value).
    function countReading() as String {
        var type = slotType(SLOT_COUNT);
        if (type == null || type == Complications.COMPLICATION_TYPE_STEPS) {
            var steps = mData.steps;
            return (steps != null ? FaceKit.thousands(steps) : "--") + " STEPS";
        }
        var t = slotText(SLOT_COUNT);
        if (t == null) {
            return FaceFormat.NO_VALUE;
        }
        return (t[1].length() > 0 ? t[0] + " " + t[1] : t[0]).toUpper();
    }

    // Centre of lug i (0 = 12 o'clock, clockwise), in px.
    private function lug(i as Number) as [Float, Float] {
        return ShopKit.polar(i * 72, LUG_R, 0, C, C, mScale);
    }

    private function drawNut(dc as Dc, i as Number, seq as Number, done as Number) as Void {
        var on = seq <= done;
        var p = FaceKit.clockPoint(i * 72, LUG_R);
        var hex = ShopKit.hexagon(C + p[0], C + p[1], 24, mScale);
        dc.setColor(ink(on ? mAccent : 0x141517), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(hex);
        dc.setColor(ink(on ? mAccent : ShopKit.STEEL), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
        ShopKit.outline(dc, hex);
        dc.setPenWidth(1);
        dc.setColor(ink(on ? GROUND : ShopKit.SOFT), Graphics.COLOR_TRANSPARENT);
        dc.drawText((C + p[0]) * mScale, (C + p[1]) * mScale, mFontSeq, seq.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A combination wrench along deg: box end round the pivot, shaft, open end at the tip
    // (its jaws open outwards). Sizes in design px.
    private function drawWrench(dc as Dc, deg as Float, headR as Number, head as Number, shaft as Number,
            shaftLen as Number, ring as Number, hole as Number, color as Number) as Void {
        dc.setColor(ink(color), Graphics.COLOR_TRANSPARENT);
        ShopKit.bar(dc, deg, -2, shaftLen, shaft * 2, mScale);
        var h = ShopKit.polar(deg, headR, 0, C, C, mScale);
        var arcR = (head * 0.7f) * mScale;
        FaceKit.roundArc(dc, h[0], h[1], arcR, deg + 35, deg + 325, FaceKit.penWidth(head * 0.6f, mScale));
        dc.fillCircle(C * mScale, C * mScale, ring * mScale);
        dc.setColor(ink(HUB), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(C * mScale, C * mScale, hole * mScale);
    }

    // Always-On: nut outlines (torqued ones in the accent) and a thin hour and minute hand.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hourDeg as Float, done as Number) as Void {
        dc.setColor(ink(Graphics.COLOR_BLACK), Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        var cx = C + shift[0];
        var cy = C + shift[1];
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        for (var i = 0; i < 5; i++) {
            var p = FaceKit.clockPoint(i * 72, LUG_R);
            dc.setColor(STAR.indexOf(i) + 1 <= done ? mAccent : ShopKit.DARK_STEEL, Graphics.COLOR_TRANSPARENT);
            ShopKit.outline(dc, ShopKit.hexagon(cx + p[0], cy + p[1], 22, mScale));
        }
        dc.setColor(ink(ShopKit.AOD_TEXT), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(4.0f, mScale));
        var hTip = ShopKit.polar(hourDeg, 110, 0, cx, cy, mScale);
        var mTip = ShopKit.polar(clock.min * 6, 168, 0, cx, cy, mScale);
        dc.drawLine(cx * mScale, cy * mScale, hTip[0], hTip[1]);
        dc.drawLine(cx * mScale, cy * mScale, mTip[0], mTip[1]);
        dc.setPenWidth(1);
        dc.fillCircle(cx * mScale, cy * mScale, 6 * mScale);
    }
}
