import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Meridian: a 24-hour dial (noon at the top) with the sun's arc, the night's sleep and a
// now-marker, or three activity rings; heavy/light time, one focus metric with four
// mini bars, and a bottom line (sunset, weather, next event). Geometry follows the
// canvas mockup (Main.dc.html, 454 px); every coordinate is in design pixels.
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;

    // Palette: AMOLED, or the mockup's MIP theme (64 colours: channels 00/55/AA/FF) on MIP
    // screens, set in onLayout. dim is brighter than the mockup's 0x8E8B85 so labels read on
    // the watch.
    private var mInk as Number = 0xF3F1EC;
    private var mDim as Number = 0xA3A09A;
    private var mTrack as Number = 0x2B2A28;
    private var mSun as Number = 0xF2B544;
    private var mSunSoft as Number = 0x5A4520;
    private var mSleep as Number = 0x6F7CFF;
    // Always-On
    private const AOD_HOURS = 0xB9B6B0;
    private const AOD_MINUTES = 0x8E8B85;
    private const AOD_TICK = 0x4A4A46;
    // Burn-in shift per minute: >= 14 px spread over any 4 minutes, searched with tools/aod-optimize.ps1
    private const AOD_SHIFTS = [[0, -10], [9, -3], [-10, 4], [3, 10], [0, -10], [10, -3], [-10, 4], [4, 10]];

    // Dial
    private const RING_R = 207.0f;
    private const DAY_W = 12.0f;
    private const ACT_W = 9.0f;
    private const ACT_STEP = 14.0f;

    // Centre column (design px; measured from the mockup)
    private const DATE_Y = 126.0f;
    private const TIME_Y = 192.5f;         // digit centre
    private const TIME_BASE = 233.0f;      // digit baseline
    private const FOCUS_BASE = 285.0f;
    private const BARS_Y = 306.0f;
    private const LINE_Y = 335.0f;

    enum { RING_DAY = 0, RING_ACTIVITY = 1 }
    enum { FOCUS_BATTERY = 0, FOCUS_STEPS = 1, FOCUS_HEART = 2, FOCUS_STRESS = 3, FOCUS_RESP = 4 }
    enum { LINE_SMART = 0, LINE_SUNSET = 1, LINE_WEATHER = 2, LINE_EVENT = 3 }

    // The focus metrics that get a bar (settings Bar*), in this order
    private const BAR_KEYS = ["BarBattery", "BarSteps", "BarHeart", "BarStress", "BarResp"] as Array<String>;
    private const BAR_DEFAULTS = [1, 1, 1, 1, 0] as Array<Number>;
    private const BAR_W = 40.0f;
    private const BAR_GAP = 8.0f;

    // Data slots (on-watch editor): 1 = the focus row, 2 = the bottom line. A picked system
    // field replaces the face's own text there; without one (or before it has a value) the
    // face shows its own. Boxes in design px: centred, SLOT_W wide.
    enum { SLOT_FOCUS = 1, SLOT_LINE = 2 }
    private const SLOT_W = 300.0f;
    private const ICON_NONE = -1;

    private var mRingMode as Number = RING_DAY;
    private var mFocus as Number = FOCUS_BATTERY;
    private var mBars as Array<Number> = [FOCUS_BATTERY, FOCUS_STEPS, FOCUS_HEART, FOCUS_STRESS] as Array<Number>;
    private var mLine as Number = LINE_SMART;
    private var mSeconds as Boolean = false;
    private var mAodRing as Boolean = true;
    // DateFormat setting (FaceFormat.DATE_*), resolved against the watch when drawn


    private var mFontHours as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontMinutes as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontValue as FontType = Graphics.FONT_SMALL;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontDateBold as FontType = Graphics.FONT_XTINY;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;
    private var mFontLine as FontType = Graphics.FONT_XTINY;
    private var mFontSeconds as FontType = Graphics.FONT_TINY;

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0xFF6A3D, FaceFormat.DATE_WATCH);
        loadSettings();
    }

    function onLayout(dc as Dc) as Void {
        FaceCoreView.onLayout(dc);
        if (!mAmoled) {
            mInk = 0xFFFFFF;
            mDim = 0xAAAAAA;
            mTrack = 0x555555;
            mSun = 0xFFAA00;
            mSunSoft = 0xAA5500;
            mSleep = 0x00AAFF;
        }
    }

    function loadFonts() as Void {
        var f = loadFontSet([Rez.Fonts.Hours, Rez.Fonts.Minutes, Rez.Fonts.Value, Rez.Fonts.Date, Rez.Fonts.DateBold, Rez.Fonts.Label, Rez.Fonts.Line, Rez.Fonts.Seconds] as Array<ResourceId>,
            [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_SMALL, Graphics.FONT_XTINY, Graphics.FONT_XTINY, Graphics.FONT_XTINY, Graphics.FONT_XTINY, Graphics.FONT_TINY] as Array<FontType>);
        mFontHours = f[0];
        mFontMinutes = f[1];
        mFontValue = f[2];
        mFontDate = f[3];
        mFontDateBold = f[4];
        mFontLabel = f[5];
        mFontLine = f[6];
        mFontSeconds = f[7];
    }

    // ---- Settings -----------------------------------------------------------

    function loadSettings() as Void {
        mAccent = FaceKit.prop("AccentColor", 0xFF6A3D);
        mRingMode = FaceKit.prop("RingMode", RING_DAY);
        mLine = FaceKit.prop("BottomLine", LINE_SMART);
        mSeconds = FaceKit.prop("ShowSeconds", 0) == 1;
        mAodRing = FaceKit.prop("AodRing", 1) == 1;
        mDateSetting = FaceKit.prop("DateFormat", FaceFormat.DATE_WATCH);
        var bars = [] as Array<Number>;
        for (var i = 0; i < BAR_KEYS.size(); i++) {
            if (FaceKit.prop(BAR_KEYS[i], BAR_DEFAULTS[i]) == 1) {
                bars.add(i);
            }
        }
        // The focus metric: the phone setting, or the bar tapped on the watch, whichever
        // changed last
        var focus = FaceKit.prop("Focus", FOCUS_BATTERY);
        var tapped = null;
        try {
            var t = Application.Storage.getValue("tapFocus");
            tapped = t instanceof Number ? t : null;
        } catch (e) {
            tapped = null;
        }
        mFocus = FaceEditor.pick("edFocus", focus, tapped, FOCUS_BATTERY);
        if (bars.size() == 0) {
            bars.add(mFocus);
        }
        mBars = bars;
        var editor = FaceEditor.settingsFor(null);
        if (editor == null) {
            return;
        }
        if (mEditMode) {
            applyEditor(editor);
            return;
        }
        // Outside the editor, whichever of phone and editor changed the setting last wins;
        // the data slots exist only in the editor
        applySlots(editor);
        mRingMode = FaceEditor.pick("edRing", mRingMode, editorRing(editor), RING_DAY);
        mAccent = FaceEditor.pick("edAccent", mAccent, editorAccent(editor), 0xFF6A3D);
    }

    // Watch face editor (while editing): style 1 = day timeline, 2 = activity rings; accent colour.
    function applyEditor(settings as Application.WatchFaceConfig.Settings) as Void {
        var ring = editorRing(settings);
        if (ring != null) {
            mRingMode = ring;
        }
        var accent = editorAccent(settings);
        if (accent != null) {
            mAccent = accent;
        }
        applySlots(settings);
    }

    private function editorRing(settings as Application.WatchFaceConfig.Settings) as Number or Null {
        var style = settings.styleId;
        return (style != null && style >= 1 && style <= 2) ? style - 1 : null;
    }

    private function editorAccent(settings as Application.WatchFaceConfig.Settings) as Number or Null {
        var accent = settings.accentColor;
        return (accent != null && accent.color instanceof Number) ? accent.color as Number : null;
    }

    // ---- Drawing --------------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        dc.setColor(ink(Graphics.COLOR_BLACK), Graphics.COLOR_BLACK);
        dc.clear();
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var nowH = clock.hour + clock.min / 60.0f;

        if (alwaysOn()) {
            drawAlwaysOn(dc, clock, now, nowH);
            return;
        }

        if (mRingMode == RING_ACTIVITY) {
            drawActivityRings(dc, 0.0f, 0.0f, false);
        } else {
            drawDayDial(dc, nowH, 0.0f, 0.0f, false);
        }
        drawDate(dc, now, 0.0f, 0.0f, false);
        drawTime(dc, clock, mFontHours, mInk, mInk, 0.0f, 0.0f, mSeconds && mAwake);
        drawBars(dc);
        for (var slot = SLOT_FOCUS; slot <= SLOT_LINE; slot++) {
            if (slot != mEditingSlot) {
                drawSlot(dc, slot);
            }
        }
    }

    // ---- Data slots -----------------------------------------------------------

    function slots() as Array<Number> {
        return [SLOT_FOCUS, SLOT_LINE] as Array<Number>;
    }

    // The focus row from cap top of the label to below the value; the bottom line around
    // its icon and text. Neither is drawn in Always-On.
    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        var top;
        var h;
        if (slot == SLOT_FOCUS) {
            top = FOCUS_BASE - 30;
            h = 36;
        } else if (slot == SLOT_LINE) {
            top = LINE_Y - 14;
            h = 28;
        } else {
            return null;
        }
        return [((C - SLOT_W / 2) * mScale).toNumber(), (top * mScale).toNumber(),
            (SLOT_W * mScale).toNumber(), (h * mScale).toNumber()] as [Number, Number, Number, Number];
    }

    function drawSlot(dc as Dc, slot as Number) as Void {
        if (slot == SLOT_FOCUS) {
            drawFocus(dc);
        } else if (slot == SLOT_LINE) {
            var clock = System.getClockTime();
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            FaceDemo.time(clock, now);
            drawBottomLine(dc, clock.hour + clock.min / 60.0f);
        }
    }

    // Always-On, as ApexFace: date, light hours, dim minutes and the four major ticks, plus
    // (AodRing) the dial or the activity rings as hairlines. Everything moves by AOD_SHIFTS
    // each minute against burn-in; under 10 % of the pixels lit.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, now as Gregorian.Info, nowH as Float) as Void {
        var shift = AOD_SHIFTS[clock.min % AOD_SHIFTS.size()] as Array<Number>;
        var dx = shift[0].toFloat();
        var dy = shift[1].toFloat();
        drawAodTicks(dc, dx, dy);
        if (mAodRing) {
            if (mRingMode == RING_ACTIVITY) {
                drawActivityRings(dc, dx, dy, true);
            } else {
                drawDayDial(dc, nowH, dx, dy, true);
            }
        }
        drawDate(dc, now, dx, dy, true);
        drawTime(dc, clock, mFontMinutes, AOD_HOURS, AOD_MINUTES, dx, dy, false);
    }

    // 00 / 06 / 12 / 18 (or 12 / 3 / 6 / 9 inside the activity rings) ticks.
    private function drawAodTicks(dc as Dc, dx as Float, dy as Float) as Void {
        var cx = (C + dx) * mScale;
        var cy = (C + dy) * mScale;
        dc.setColor(ink(AOD_TICK), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(3.0f, mScale));
        var r0 = mRingMode == RING_ACTIVITY ? 158 : 176;
        for (var i = 0; i < 4; i++) {
            var a = FaceKit.clockPoint(i * 90, r0);
            var b = FaceKit.clockPoint(i * 90, r0 + 14);
            dc.drawLine(cx + a[0] * mScale, cy + a[1] * mScale, cx + b[0] * mScale, cy + b[1] * mScale);
        }
        dc.setPenWidth(1);
    }

    private function drawDayDial(dc as Dc, nowH as Float, dx as Float, dy as Float, aod as Boolean) as Void {
        var cx = (C + dx) * mScale;
        var cy = (C + dy) * mScale;
        var r = (aod ? RING_R - 4 : RING_R) * mScale;
        var w = FaceKit.penWidth(aod ? 3.0f : DAY_W, mScale);

        if (!aod) {
            dc.setColor(ink(mTrack), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
            dc.drawCircle(cx, cy, r);
        }

        var sleep = mData.sleepTime;
        var wake = mData.wakeTime;
        if (sleep != null && wake != null) {
            dc.setColor(aod ? 0x2A2F66 : FaceKit.mix(mSleep, 0x000000, 0.85f), Graphics.COLOR_TRANSPARENT);
            FaceKit.roundArc(dc, cx, cy, r, hourDeg(sleep), hourDeg(wake), w);
        }

        var rise = mData.sunrise;
        var set = mData.sunset;
        if (rise != null && set != null) {
            var doneTo = nowH < rise ? rise : (nowH > set ? set : nowH);
            if (doneTo < set) {
                dc.setColor(ink(aod ? 0x3A2D16 : mSunSoft), Graphics.COLOR_TRANSPARENT);
                FaceKit.roundArc(dc, cx, cy, r, hourDeg(doneTo), hourDeg(set), w);
            }
            if (doneTo > rise) {
                dc.setColor(ink(aod ? 0x7A5B22 : mSun), Graphics.COLOR_TRANSPARENT);
                FaceKit.roundArc(dc, cx, cy, r, hourDeg(rise), hourDeg(doneTo), w);
            }
        }

        if (!aod) {
            for (var h = 0; h < 24; h++) {
                var major = h % 6 == 0;
                dc.setColor(ink(major ? mDim : mTrack), Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(FaceKit.penWidth(major ? 3.0f : 2.0f, mScale));
                var a = FaceKit.clockPoint(hourDeg(h.toFloat()), major ? 176 : 184);
                var b = FaceKit.clockPoint(hourDeg(h.toFloat()), 192);
                dc.drawLine(cx + a[0] * mScale, cy + a[1] * mScale, cx + b[0] * mScale, cy + b[1] * mScale);
            }
            dc.setColor(ink(mDim), Graphics.COLOR_TRANSPARENT);
            var labels = ["00", "06", "12", "18"];
            for (var i = 0; i < 4; i++) {
                var p = FaceKit.clockPoint(hourDeg(i * 6.0f), 160);
                dc.drawText(cx + p[0] * mScale, cy + p[1] * mScale, mFontLabel, labels[i],
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // Now-marker
        var n = FaceKit.clockPoint(hourDeg(nowH), aod ? RING_R - 4 : RING_R);
        var nx = cx + n[0] * mScale;
        var ny = cy + n[1] * mScale;
        if (aod) {
            dc.setColor(ink(0x9A9790), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(nx, ny, 4 * mScale);
            return;
        }
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.5f, mScale));
        dc.drawCircle(nx, ny, 14 * mScale);
        dc.setColor(ink(Graphics.COLOR_BLACK), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(nx, ny, 10 * mScale);
        dc.setColor(ink(mInk), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(nx, ny, 7 * mScale);
        dc.setPenWidth(1);
    }

    // Outer: steps / step goal (accent); middle: intensity minutes / weekly goal (sun);
    // inner: floors / floor goal (sleep blue). Each starts at 12 o'clock.
    // Always-On: progress only, as dimmed hairlines.
    private function drawActivityRings(dc as Dc, dx as Float, dy as Float, aod as Boolean) as Void {
        var cx = (C + dx) * mScale;
        var cy = (C + dy) * mScale;
        var w = FaceKit.penWidth(aod ? 3.0f : ACT_W, mScale);
        var fractions = [
            FaceData.fraction(mData.steps, mData.stepGoal),
            FaceData.fraction(mData.intensity, mData.intensityGoal),
            FaceData.fraction(mData.floors, mData.floorsGoal)
        ];
        var colors = [mAccent, mSun, mSleep];
        for (var i = 0; i < 3; i++) {
            var r = ((aod ? RING_R - 4 : RING_R) - i * ACT_STEP) * mScale;
            if (!aod) {
                dc.setColor(ink(mTrack), Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(w);
                dc.drawCircle(cx, cy, r);
            }
            var f = fractions[i];
            if (f != null && f > 0.0f) {
                var color = colors[i] as Number;
                dc.setColor(aod ? FaceKit.mix(color, 0x000000, 0.5f) : color, Graphics.COLOR_TRANSPARENT);
                FaceKit.roundArc(dc, cx, cy, r, 0.0f, 360.0f * f, w);
            }
        }
        dc.setPenWidth(1);
    }

    // "SAT" in the accent, then "10 OCT" (or "10-10-2026" by the DateFormat setting),
    // letter-spaced, centred.
    private function drawDate(dc as Dc, now as Gregorian.Info, dx as Float, dy as Float, aod as Boolean) as Void {
        var track = 3.0f * mScale;
        var day = FaceKit.dayName(now.day_of_week as Number);
        var rest = FaceKit.dateRest(now.day as Number, now.month as Number, now.year as Number,
            FaceKit.dateFormat(mDateSetting));
        var wDay = FaceKit.trackedWidth(dc, mFontDateBold, day, track);
        var wRest = FaceKit.trackedWidth(dc, mFontDate, rest, track);
        var gap = 13.0f * mScale;
        var left = (C + dx) * mScale - (wDay + gap + wRest) / 2;
        var y = (DATE_Y + dy) * mScale;
        dc.setColor(aod ? FaceKit.mix(mAccent, 0x000000, 0.7f) : mAccent, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, left, y, mFontDateBold, day, track, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(ink(aod ? AOD_MINUTES : mDim), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, left + wDay + gap, y, mFontDate, rest, track, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Heavy hours, light minutes (tight: -5 px tracking), optional accent seconds on the
    // same baseline. The group is centred.
    private function drawTime(dc as Dc, clock as System.ClockTime, hoursFont as FontType, hoursColor as Number,
            minutesColor as Number, dx as Float, dy as Float, seconds as Boolean) as Void {
        var track = -5.0f * mScale;
        var hours = FaceKit.hourText(clock.hour);
        var minutes = FaceKit.twoDigits(clock.min);
        var wH = FaceKit.trackedWidth(dc, hoursFont, hours, track);
        var wM = FaceKit.trackedWidth(dc, mFontMinutes, minutes, track);
        var gap = 6.0f * mScale;
        var sec = FaceKit.twoDigits(clock.sec);
        var wS = seconds ? gap + dc.getTextWidthInPixels(sec, mFontSeconds) : 0.0f;
        var left = (C + dx) * mScale - (wH + gap + wM + wS) / 2;
        var y = (TIME_Y + dy) * mScale;
        dc.setColor(ink(hoursColor), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, left, y, hoursFont, hours, track, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(ink(minutesColor), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, left + wH + gap, y, mFontMinutes, minutes, track, Graphics.TEXT_JUSTIFY_LEFT);
        if (seconds) {
            dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
            var top = (TIME_BASE + dy) * mScale - Graphics.getFontAscent(mFontSeconds);
            dc.drawText(left + wH + gap + wM + gap, top, mFontSeconds, sec, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // [label, value, unit, fill 0..1 or null] of a focus metric.
    private function metric(id as Number) as [String, String, String, Float or Null] {
        switch (id) {
            case FOCUS_STEPS: {
                var steps = mData.steps;
                var f = FaceData.fraction(steps, mData.stepGoal);
                return ["STEPS", steps != null ? FaceKit.thousands(steps) : "--",
                    f != null ? Math.round(f * 100).toNumber().toString() + "%" : "", f];
            }
            case FOCUS_HEART: {
                var hr = mData.heartRate();
                return ["HEART", hr != null ? hr.toString() : "--", "bpm",
                    hr != null ? FaceKit.clamp01((hr - 40) / 120.0f) : null];
            }
            case FOCUS_STRESS: {
                var s = mData.stress;
                var level = s == null ? "" : (s <= 25 ? "rest" : (s <= 50 ? "low" : (s <= 75 ? "med" : "high")));
                return ["STRESS", s != null ? s.toString() : "--", level, s != null ? FaceKit.clamp01(s / 100.0f) : null];
            }
            case FOCUS_RESP: {
                // breaths per minute; the bar spans 8 (calm) to 24
                var r = mData.respiration();
                return ["RESPIRATION", r != null ? r.toString() : "--", "brpm",
                    r != null ? FaceKit.clamp01((r - 8) / 16.0f) : null];
            }
        }
        var bb = mData.bodyBattery;
        return ["BODY BATTERY", bb != null ? bb.toString() : "--", "/100", bb != null ? FaceKit.clamp01(bb / 100.0f) : null];
    }

    // The focus row: [label, value, unit, fill] of the field picked for the focus slot, or
    // of the focus metric without one.
    function focusRow(picked as [String, String] or Null) as [String, String, String, Float or Null] {
        if (picked != null) {
            return [picked[1], picked[0], "", null];
        }
        return metric(mFocus);
    }

    // Label, value and unit on one baseline, centred. A row wider than the slot (a long
    // system field) drops the label's letter-spacing, then takes a system font for the value.
    private function drawFocus(dc as Dc) as Void {
        var m = focusRow(slotText(SLOT_FOCUS));
        var maxW = (SLOT_W - 4) * mScale;
        var gap = 8.0f * mScale;
        var valueFont = mFontValue;
        var wV = dc.getTextWidthInPixels(m[1], valueFont);
        var wU = m[2].length() > 0 ? gap + dc.getTextWidthInPixels(m[2], mFontLabel) : 0;
        var track = fitTracking(dc, mFontLabel, m[0], 2.0f * mScale, maxW - gap - wV - wU);
        var wL = FaceKit.trackedWidth(dc, mFontLabel, m[0], track);
        if (wL + gap + wV + wU > maxW) {
            valueFont = Graphics.FONT_XTINY;
            wV = dc.getTextWidthInPixels(m[1], valueFont);
        }
        if (wL == 0) {
            gap = 0.0f;
        }
        var left = C * mScale - (wL + gap + wV + wU) / 2;
        var base = FOCUS_BASE * mScale;
        var labelY = base - Graphics.getFontAscent(mFontLabel) / 2.0f;
        dc.setColor(ink(mDim), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, left, labelY, mFontLabel, m[0], track, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(ink(mInk), Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + wL + gap, base - Graphics.getFontAscent(valueFont), valueFont, m[1], Graphics.TEXT_JUSTIFY_LEFT);
        if (m[2].length() > 0) {
            dc.setColor(ink(mDim), Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + wL + gap + wV + gap, base - Graphics.getFontAscent(mFontLabel), mFontLabel, m[2],
                Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // A mini bar per chosen focus metric (Bar* settings; by default battery, steps, heart,
    // stress); the focus metric's in the accent. On touch watches a tap on a bar makes it
    // the focus (onFacePress).
    private function drawBars(dc as Dc) as Void {
        var w = BAR_W * mScale;
        // whole pixels, at least 3: the 218 px screen drops a 2.4 px rounded bar entirely
        var h = Math.round(5.0f * mScale).toFloat();
        h = h < 3.0f ? 3.0f : h;
        var top = Math.round(BARS_Y * mScale - h / 2).toFloat();
        // a field picked for the focus slot replaces the focus metric: no bar in the accent
        var focus = slotText(SLOT_FOCUS) == null ? mFocus : -1;
        for (var i = 0; i < mBars.size(); i++) {
            var x = barLeft(i) * mScale;
            var id = mBars[i];
            dc.setColor(ink(mTrack), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, top, w, h, h / 2);
            var f = metric(id)[3];
            if (f != null && f > 0.0f) {
                var fw = w * f;
                dc.setColor(ink(id == focus ? mAccent : mDim), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x, top, fw < h ? h : fw, h, h / 2);
            }
        }
    }

    // Left edge of bar i in design px (the row is centred).
    private function barLeft(i as Number) as Float {
        var n = mBars.size();
        return C - (n * BAR_W + (n - 1) * BAR_GAP) / 2 + i * (BAR_W + BAR_GAP);
    }

    // A tap on a bar (the mockup's 10 px touch padding above and below, half the gap
    // either side) makes its metric the focus until the next tap or phone setting change.
    function onFacePress(x as Number, y as Number) as Boolean {
        if (alwaysOn() || mEditMode) {
            return false;
        }
        var dx = x / mScale;
        var dy = y / mScale;
        if (dy < BARS_Y - 14 || dy > BARS_Y + 14) {
            return false;
        }
        for (var i = 0; i < mBars.size(); i++) {
            var left = barLeft(i) - BAR_GAP / 2;
            if (dx >= left && dx < left + BAR_W + BAR_GAP) {
                try {
                    Application.Storage.setValue("tapFocus", mBars[i]);
                } catch (e) {
                    return false;
                }
                loadSettings();
                WatchUi.requestUpdate();
                return true;
            }
        }
        return false;
    }

    // Icon + text: sunset countdown, weather, or the next calendar event; or the field
    // picked for the bottom-line slot ("VO2 MAX 52"), without an icon. Text wider than the
    // slot takes a system font.
    private function drawBottomLine(dc as Dc, nowH as Float) as Void {
        var line = lineOf(slotText(SLOT_LINE), nowH);
        if (line == null) {
            return;
        }
        var hasIcon = line[0] != ICON_NONE;
        var icon = hasIcon ? 16.0f * mScale : 0.0f;
        var gap = hasIcon ? 8.0f * mScale : 0.0f;
        var font = mFontLine;
        var wT = dc.getTextWidthInPixels(line[1], font);
        if (icon + gap + wT > (SLOT_W - 4) * mScale) {
            font = Graphics.FONT_XTINY;
            wT = dc.getTextWidthInPixels(line[1], font);
        }
        var left = C * mScale - (icon + gap + wT) / 2;
        var y = LINE_Y * mScale;
        if (hasIcon) {
            drawIcon(dc, line[0], left, y - icon / 2, icon);
        }
        dc.setColor(ink(mDim), Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + icon + gap, y, font, line[1], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // [icon, text] of the bottom line: the picked field ("LABEL value", no icon), or the
    // face's own line; null when there is nothing to show.
    function lineOf(picked as [String, String] or Null, nowH as Float) as [Number, String] or Null {
        if (picked != null) {
            var text = picked[1].length() > 0 ? picked[1] + " " + picked[0] : picked[0];
            return [ICON_NONE, text];
        }
        return bottomLine(nowH);
    }

    enum { ICON_SUNSET = 0, ICON_SUNRISE = 1, ICON_WEATHER = 2, ICON_EVENT = 3 }

    // [icon, text] or null when there is nothing to show.
    private function bottomLine(nowH as Float) as [Number, String] or Null {
        var mode = mLine;
        var sun = sunLine(nowH);
        var weather = weatherLine();
        var event = mData.nextEvent();
        if (mode == LINE_SUNSET) {
            return sun;
        } else if (mode == LINE_WEATHER) {
            return weather != null ? weather : sun;
        } else if (mode == LINE_EVENT) {
            return event != null ? [ICON_EVENT, "Next event " + event] : sun;
        }
        // Smart: the sunset countdown while the sun is up, otherwise the weather,
        // otherwise the next event, otherwise sunrise.
        var set = mData.sunset;
        var rise = mData.sunrise;
        if (rise != null && set != null && nowH >= rise && nowH < set) {
            return sun;
        }
        if (weather != null) {
            return weather;
        }
        if (event != null) {
            return [ICON_EVENT, "Next event " + event];
        }
        return sun;
    }

    private function sunLine(nowH as Float) as [Number, String] or Null {
        var set = mData.sunset;
        var rise = mData.sunrise;
        if (set == null || rise == null) {
            return null;
        }
        if (nowH >= rise && nowH < set) {
            var minutes = Math.round((set - nowH) * 60).toNumber();
            return [ICON_SUNSET, "Sunset in " + FaceKit.durationText(minutes)];
        }
        return [ICON_SUNRISE, "Sunrise " + FaceKit.clockText(rise)];
    }

    private function weatherLine() as [Number, String] or Null {
        var t = mData.temperature;
        if (t == null) {
            return null;
        }
        var text = t.toString() + "°";
        var c = mData.conditionText();
        if (c.length() > 0) {
            text += " · " + c;
        }
        return [ICON_WEATHER, text];
    }

    // Stroke icons from the mockup, drawn in a 24-unit box scaled to size px.
    private function drawIcon(dc as Dc, icon as Number, x as Float, y as Float, size as Float) as Void {
        var k = size / 24.0f;
        dc.setColor(ink(mSun), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        if (icon == ICON_SUNSET || icon == ICON_SUNRISE) {
            dc.drawLine(x + 3 * k, y + 18 * k, x + 21 * k, y + 18 * k);
            dc.drawArc(x + 12 * k, y + 18 * k, 5 * k, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
            dc.drawLine(x + 12 * k, y + 4 * k, x + 12 * k, y + 10 * k);
            if (icon == ICON_SUNSET) {
                dc.drawLine(x + 9 * k, y + 7 * k, x + 12 * k, y + 10 * k);
                dc.drawLine(x + 15 * k, y + 7 * k, x + 12 * k, y + 10 * k);
            } else {
                dc.drawLine(x + 9 * k, y + 7 * k, x + 12 * k, y + 4 * k);
                dc.drawLine(x + 15 * k, y + 7 * k, x + 12 * k, y + 4 * k);
            }
        } else if (icon == ICON_WEATHER) {
            dc.drawLine(x + 7 * k, y + 18 * k, x + 17 * k, y + 18 * k);
            dc.drawArc(x + 17 * k, y + 14 * k, 4 * k, Graphics.ARC_COUNTER_CLOCKWISE, 270, 90);
            dc.drawArc(x + 11.5f * k, y + 12 * k, 5.5f * k, Graphics.ARC_COUNTER_CLOCKWISE, 20, 170);
            dc.drawArc(x + 7 * k, y + 15 * k, 3 * k, Graphics.ARC_COUNTER_CLOCKWISE, 90, 270);
        } else {
            dc.drawRectangle(x + 4 * k, y + 6 * k, 16 * k, 14 * k);
            dc.drawLine(x + 4 * k, y + 10 * k, x + 20 * k, y + 10 * k);
            dc.drawLine(x + 8 * k, y + 3 * k, x + 8 * k, y + 7 * k);
            dc.drawLine(x + 16 * k, y + 3 * k, x + 16 * k, y + 7 * k);
        }
        dc.setPenWidth(1);
    }

    // Clock angle of an hour of the day: noon at the top, midnight at the bottom.
    private function hourDeg(h as Float) as Float {
        return h * 15.0f + 180.0f;
    }
}
