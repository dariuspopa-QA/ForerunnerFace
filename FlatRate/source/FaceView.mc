import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Flat Rate: a shift clock for the shop. The ring fills over the shift (its last tenth in
// red); ON CLOCK, BOOK (the shift length) and LEFT under the time; a hazard-stripe band
// names the next stop (break or shift end). Shift start, length, break, bay and the job
// line are phone settings. Geometry follows the canvas mockup (FlatRate.dc.html, 454 px).
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;
    private const TIME_Y = 165.0f;
    private const BAND_Y = 326.0f;
    private const BAND_H = 40.0f;
    private const LATE = 0xFF5A3C;
    private const BOTTOM_Y = 388.0f;

    // Editor data slot (resources/configs/watchface.xml) and its tap box (design px): the
    // bottom line's reading after the date (heart rate by default)
    private const SLOT_BOTTOM = 1;
    private const SLOT_BOX_W = 300.0f;
    private const SLOT_BOX_H = 36.0f;

    private var mStart as Number = 420;       // minutes after midnight
    private var mLength as Number = 480;      // minutes
    private var mBreak as Number = 720;       // minutes after midnight, -1 = none
    private var mBay as Number = 3;           // 0 = not shown
    private var mRo as Number = 0;            // repair order number, 0 = not shown
    private var mJob as String = "ON THE CLOCK";

    private var mFontTime as FontType = Graphics.FONT_NUMBER_HOT;
    private var mFontTimeAod as FontType = Graphics.FONT_NUMBER_HOT;
    private var mFontTop as FontType = Graphics.FONT_XTINY;
    private var mFontJob as FontType = Graphics.FONT_TINY;
    private var mFontBoxLabel as FontType = Graphics.FONT_XTINY;
    private var mFontBoxValue as FontType = Graphics.FONT_TINY;
    private var mFontBand as FontType = Graphics.FONT_XTINY;
    private var mFontBottom as FontType = Graphics.FONT_XTINY;

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0xD7FF1F, FaceFormat.DATE_NAMED);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = loadFontSet([Rez.Fonts.Time, Rez.Fonts.TimeAod, Rez.Fonts.Top, Rez.Fonts.Job, Rez.Fonts.BoxLabel, Rez.Fonts.BoxValue, Rez.Fonts.Band, Rez.Fonts.Bottom] as Array<ResourceId>,
            [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_XTINY, Graphics.FONT_XTINY] as Array<FontType>);
        mFontTime = f[0];
        mFontTimeAod = f[1];
        mFontTop = f[2];
        mFontJob = f[3];
        mFontBoxLabel = f[4];
        mFontBoxValue = f[5];
        mFontBand = f[6];
        mFontBottom = f[7];
    }

    // Shift times, bay and job name; accent and date format come from FaceCoreView.
    function loadPhoneSettings() as Void {
        mStart = FaceKit.prop("ShiftStart", 420);
        mLength = FaceKit.prop("ShiftLength", 480);
        mBreak = FaceKit.prop("BreakTime", 720);
        mBay = FaceKit.prop("Bay", 3);
        mRo = FaceKit.prop("RepairOrder", 0);
        mJob = "ON THE CLOCK";
        try {
            var job = Application.Properties.getValue("JobName");
            if (job instanceof String && job.length() > 0) {
                mJob = job.toUpper();
            }
        } catch (e) {
        }
        if (mLength < 30) {
            mLength = 30;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var hm = FaceKit.hourText(clock.hour) + ":" + FaceKit.twoDigits(clock.min);
        var nowMin = clock.hour * 60 + clock.min + clock.sec / 60.0f;
        var elapsed = nowMin - mStart;
        elapsed = elapsed < 0 ? 0.0f : (elapsed > mLength ? mLength.toFloat() : elapsed);
        var progress = elapsed / mLength;

        if (alwaysOn()) {
            drawAlwaysOn(dc, clock, hm, progress, nowMin);
            return;
        }
        dc.setColor(ink(ShopKit.GROUND), ShopKit.GROUND);
        dc.clear();
        var mid = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var lit = Math.round(progress * 100).toNumber();
        for (var i = 0; i < 100; i++) {
            dc.setColor(ink(i < lit ? (i >= 90 ? LATE : mAccent) : 0x1E2022), Graphics.COLOR_TRANSPARENT);
            ShopKit.bar(dc, i * 3.6f, 205, 223, 4, mScale);
        }

        // "RO 4471 · BAY 3", either part hidden when set to 0
        var top = mRo > 0 ? "RO " + mRo : "";
        if (mBay > 0) {
            top += (top.length() > 0 ? " · " : "") + "BAY " + mBay;
        }
        if (top.length() > 0) {
            dc.setColor(ink(ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
            FaceKit.drawTracked(dc, C * mScale, 62 * mScale, mFontTop, top, 2 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(ink(ShopKit.TEXT), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, 86 * mScale, mFontJob, mJob, 1 * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(C * mScale, TIME_Y * mScale, mFontTime, hm, mid);

        var left = mLength - elapsed;
        box(dc, 0, "ON CLOCK", minutesText(elapsed), false);
        box(dc, 1, "BOOK", (mLength / 60.0f).format("%.1f") + " h", false);
        box(dc, 2, "LEFT", minutesText(left), true);

        drawBand(dc, nowMin);

        // The bottom line is the editor's data slot; the editor draws it while previewing it.
        if (mEditingSlot != SLOT_BOTTOM) {
            drawBottom(dc, now);
        }
    }

    // "SAT 11 OCT · HR 72" (the mockup), or the picked field after the date.
    private function drawBottom(dc as Dc, now as Gregorian.Info) as Void {
        var text = FaceKit.dateText(now, FaceKit.dateFormat(mDateSetting)) + " · " + bottomReading();
        dc.setColor(ink(ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, BOTTOM_Y * mScale, mFontBottom, text,
            fitTracking(dc, mFontBottom, text, 3 * mScale, SLOT_BOX_W * mScale), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Data slot (on-watch editor) ---------------------------------------------
    // 1 = the reading on the bottom line. Heart rate (the default) is the face's own
    // "HR 72"; any other field shows as "LABEL VALUE" the same way. The shift ring, boxes
    // and band stay the shift whatever the slot shows.

    function slots() as Array<Number> {
        return [SLOT_BOTTOM] as Array<Number>;
    }

    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        if (slot != SLOT_BOTTOM) {
            return null;
        }
        return [((C - SLOT_BOX_W / 2) * mScale).toNumber(), ((BOTTOM_Y - 8) * mScale).toNumber(),
            (SLOT_BOX_W * mScale).toNumber(), (SLOT_BOX_H * mScale).toNumber()];
    }

    function drawSlot(dc as Dc, slot as Number) as Void {
        if (slot == SLOT_BOTTOM) {
            drawBottom(dc, Gregorian.info(Time.now(), Time.FORMAT_SHORT));
        }
    }

    // The reading after the date: "HR 72" while the slot holds heart rate or nothing, else
    // the picked field as "LABEL VALUE" ("--" until it has a value).
    function bottomReading() as String {
        var type = slotType(SLOT_BOTTOM);
        if (type == null || type == Complications.COMPLICATION_TYPE_HEART_RATE) {
            return "HR " + ShopKit.orDash(mData.heartRate());
        }
        var t = slotText(SLOT_BOTTOM);
        if (t == null) {
            return FaceFormat.NO_VALUE;
        }
        return (t[1].length() > 0 ? t[1] + " " + t[0] : t[0]).toUpper();
    }

    // "1:36" for a number of minutes.
    private function minutesText(minutes as Float) as String {
        var m = minutes.toNumber();
        return (m / 60).toString() + ":" + FaceKit.twoDigits(m % 60);
    }

    // One of the three boxes under the time (0..2, left to right).
    private function box(dc as Dc, i as Number, label as String, value as String, accent as Boolean) as Void {
        var w = (270.0f - 16) / 3;
        var x = 92 + i * (w + 8);
        dc.setColor(ink(accent ? mAccent : 0x141516), Graphics.COLOR_TRANSPARENT);
        ShopKit.box(dc, x, 236, w, 56, 8, mScale);
        var cx = (x + w / 2) * mScale;
        dc.setColor(ink(accent ? ShopKit.GROUND : ShopKit.MUTED), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, cx, 252 * mScale, mFontBoxLabel, label,
            fitTracking(dc, mFontBoxLabel, label, 2 * mScale, (w - 6) * mScale), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(ink(accent ? ShopKit.GROUND : ShopKit.TEXT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 274 * mScale, mFontBoxValue, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // What comes next: shift start, break, shift end, or done.
    private function nextText(nowMin as Float) as String {
        var end = mStart + mLength;
        if (nowMin < mStart) {
            return "START " + clockText(mStart);
        }
        if (mBreak > mStart && mBreak < end && nowMin < mBreak) {
            return "NEXT · BREAK " + clockText(mBreak);
        }
        if (nowMin < end) {
            return "NEXT · END " + clockText(end);
        }
        return "SHIFT OVER";
    }

    private function clockText(minutes as Number) as String {
        return FaceKit.clockText(minutes / 60.0f);
    }

    // Hazard stripes across the screen with the next stop on a black plate.
    private function drawBand(dc as Dc, nowMin as Float) as Void {
        var top = BAND_Y * mScale;
        var h = BAND_H * mScale;
        dc.setClip(0, top, dc.getWidth(), h + 1);
        dc.setColor(ink(ShopKit.GROUND), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, top, dc.getWidth(), h + 1);
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        var period = 39.6f;
        for (var x = -BAND_H; x < FaceKit.DESIGN; x += period) {
            dc.fillPolygon([[x * mScale, top + h], [(x + period / 2) * mScale, top + h],
                [(x + period / 2 + BAND_H) * mScale, top], [(x + BAND_H) * mScale, top]]);
        }
        dc.clearClip();

        var text = nextText(nowMin);
        var track = 2 * mScale;
        var w = FaceKit.trackedWidth(dc, mFontBand, text, track) + 24 * mScale;
        dc.setColor(ink(ShopKit.GROUND), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(C * mScale - w / 2, top + 9 * mScale, w, h - 18 * mScale);
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, top + h / 2, mFontBand, text, track, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Always-On: thin digits, the shift as a thin arc, the next stop.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hm as String, progress as Float, nowMin as Float) as Void {
        dc.setColor(ink(Graphics.COLOR_BLACK), Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        var cx = (C + shift[0]) * mScale;
        var dy = shift[1] * mScale;
        var dim = FaceKit.mix(mAccent, 0x000000, 0.55f);
        dc.setColor(ink(dim), Graphics.COLOR_TRANSPARENT);
        FaceKit.roundArc(dc, cx, C * mScale + dy, 212 * mScale, 0.0f, progress * 360, FaceKit.penWidth(3.0f, mScale));
        FaceKit.drawTracked(dc, cx, (BAND_Y + BAND_H / 2) * mScale + dy, mFontBand, nextText(nowMin), 2 * mScale,
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(ink(ShopKit.AOD_TEXT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, TIME_Y * mScale + dy, mFontTimeAod, hm, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
