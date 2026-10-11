import Toybox.Application;
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
class FaceView extends WatchUi.WatchFace {

    private const C = FaceKit.C;
    private const GROUND = 0x0A0A0B;
    private const HUB = 0x17181A;
    private const LUG_R = 112.0f;
    // Tightening order: the lug (clockwise from 12 o'clock) torqued at each step
    private const STAR = [0, 2, 4, 1, 3] as Array<Number>;

    private var mAccent as Number = 0xFFD400;
    private var mDateSetting as Number = FaceKit.DATE_NAMED;
    private var mScale as Float = 1.0f;
    private var mAwake as Boolean = true;
    private var mEditMode as Boolean;
    private var mData as FaceData = new FaceData();

    private var mFontSeq as FontType = Graphics.FONT_SMALL;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;
    private var mFontCount as FontType = Graphics.FONT_SMALL;

    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        mEditMode = editMode;
        loadSettings();
    }

    function onLayout(dc as Dc) as Void {
        mScale = dc.getWidth() / FaceKit.DESIGN;
        try {
            mFontSeq = WatchUi.loadResource(Rez.Fonts.Seq) as FontResource;
            mFontDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
            mFontLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
            mFontCount = WatchUi.loadResource(Rez.Fonts.Count) as FontResource;
        } catch (e) {
        }
    }

    function onExitSleep() as Void {
        mAwake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        mAwake = false;
        WatchUi.requestUpdate();
    }

    function loadSettings() as Void {
        mAccent = FaceKit.prop("AccentColor", 0xFFD400);
        mDateSetting = FaceKit.prop("DateFormat", FaceKit.DATE_NAMED);
        var editor = FaceEditor.settingsFor(null);
        if (editor != null) {
            applyEditor(editor);
        }
    }

    function applyEditor(settings as Application.WatchFaceConfig.Settings) as Void {
        var accent = settings.accentColor;
        if (accent != null && accent.color instanceof Number) {
            mAccent = accent.color as Number;
        }
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

        if ((!mAwake || FaceDemo.FORCE_AOD) && !mEditMode && FaceKit.burnInProtection()) {
            drawAlwaysOn(dc, clock, hourDeg, done);
            return;
        }
        dc.setColor(GROUND, GROUND);
        dc.clear();

        dc.setColor(0x1F2124, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        dc.drawCircle(C * mScale, C * mScale, 189 * mScale);
        dc.setPenWidth(1);
        for (var i = 0; i < 60; i++) {
            var major = i % 5 == 0;
            dc.setColor(major ? ShopKit.SOFT : ShopKit.DARK_STEEL, Graphics.COLOR_TRANSPARENT);
            ShopKit.bar(dc, i * 6, major ? 201 : 211, 219, major ? 4 : 2, mScale);
        }

        // The star: a solid line between two torqued nuts, dashed ahead
        dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
        for (var k = 0; k < 5; k++) {
            var a = lug(STAR[k]);
            var b = lug(STAR[(k + 1) % 5]);
            if (k + 1 < done) {
                dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(a[0], a[1], b[0], b[1]);
            } else {
                dc.setColor(0x2C2E31, Graphics.COLOR_TRANSPARENT);
                ShopKit.dashed(dc, a[0], a[1], b[0], b[1], 6 * mScale, 6 * mScale);
            }
        }
        for (var i = 0; i < 5; i++) {
            drawNut(dc, i, STAR.indexOf(i) + 1, done);
        }

        dc.setColor(ShopKit.MUTED, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 71 * mScale, mFontDate, FaceKit.dateText(now, FaceKit.dateFormat(mDateSetting)),
            4 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        FaceKit.drawTracked(dc, C * mScale, 363 * mScale, mFontLabel, "TORQUE SEQUENCE", 3 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(C * mScale, 386 * mScale, mFontCount,
            done + " / 5 · " + (steps != null ? FaceKit.thousands(steps) : "--") + " STEPS",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(HUB, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(C * mScale, C * mScale, 35 * mScale);
        dc.setColor(0x2C2E31, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
        dc.drawCircle(C * mScale, C * mScale, 33.5f * mScale);
        dc.setPenWidth(1);

        drawWrench(dc, hourDeg, 113, 15, 5, 102, 13, 6, ShopKit.SOFT);
        drawWrench(dc, minDeg, 170, 13, 4, 160, 11, 5, ShopKit.TEXT);
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        ShopKit.bar(dc, clock.sec * 6, -30, 197, 2, mScale);
        dc.fillCircle(C * mScale, C * mScale, 6 * mScale);
    }

    // Centre of lug i (0 = 12 o'clock, clockwise), in px.
    private function lug(i as Number) as [Float, Float] {
        return ShopKit.polar(i * 72, LUG_R, 0, C, C, mScale);
    }

    private function drawNut(dc as Dc, i as Number, seq as Number, done as Number) as Void {
        var on = seq <= done;
        var p = FaceKit.clockPoint(i * 72, LUG_R);
        var hex = ShopKit.hexagon(C + p[0], C + p[1], 24, mScale);
        dc.setColor(on ? mAccent : 0x141517, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(hex);
        dc.setColor(on ? mAccent : ShopKit.STEEL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
        ShopKit.outline(dc, hex);
        dc.setPenWidth(1);
        dc.setColor(on ? GROUND : ShopKit.SOFT, Graphics.COLOR_TRANSPARENT);
        dc.drawText((C + p[0]) * mScale, (C + p[1]) * mScale, mFontSeq, seq.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A combination wrench along deg: box end round the pivot, shaft, open end at the tip
    // (its jaws open outwards). Sizes in design px.
    private function drawWrench(dc as Dc, deg as Float, headR as Number, head as Number, shaft as Number,
            shaftLen as Number, ring as Number, hole as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        ShopKit.bar(dc, deg, -2, shaftLen, shaft * 2, mScale);
        var h = ShopKit.polar(deg, headR, 0, C, C, mScale);
        var arcR = (head * 0.7f) * mScale;
        FaceKit.roundArc(dc, h[0], h[1], arcR, deg + 35, deg + 325, FaceKit.penWidth(head * 0.6f, mScale));
        dc.fillCircle(C * mScale, C * mScale, ring * mScale);
        dc.setColor(HUB, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(C * mScale, C * mScale, hole * mScale);
    }

    // Always-On: nut outlines (torqued ones in the accent) and a thin hour and minute hand.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hourDeg as Float, done as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var shift = ShopKit.shift(clock.min);
        var cx = C + shift[0];
        var cy = C + shift[1];
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        for (var i = 0; i < 5; i++) {
            var p = FaceKit.clockPoint(i * 72, LUG_R);
            dc.setColor(STAR.indexOf(i) + 1 <= done ? mAccent : ShopKit.DARK_STEEL, Graphics.COLOR_TRANSPARENT);
            ShopKit.outline(dc, ShopKit.hexagon(cx + p[0], cy + p[1], 22, mScale));
        }
        dc.setColor(ShopKit.AOD_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(4.0f, mScale));
        var hTip = ShopKit.polar(hourDeg, 110, 0, cx, cy, mScale);
        var mTip = ShopKit.polar(clock.min * 6, 168, 0, cx, cy, mScale);
        dc.drawLine(cx * mScale, cy * mScale, hTip[0], hTip[1]);
        dc.drawLine(cx * mScale, cy * mScale, mTip[0], mTip[1]);
        dc.setPenWidth(1);
        dc.fillCircle(cx * mScale, cy * mScale, 6 * mScale);
    }
}
