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
class FaceView extends WatchUi.WatchFace {

    private const C = FaceKit.C;

    // Palette (AMOLED). dim is brighter than the mockup's 0x8E8B85 so labels read on the watch.
    private const INK = 0xF3F1EC;
    private const DIM = 0xA3A09A;
    private const TRACK = 0x2B2A28;
    private const SUN = 0xF2B544;
    private const SUN_SOFT = 0x5A4520;
    private const SLEEP = 0x6F7CFF;
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
    enum { FOCUS_BATTERY = 0, FOCUS_STEPS = 1, FOCUS_HEART = 2, FOCUS_STRESS = 3 }
    enum { LINE_SMART = 0, LINE_SUNSET = 1, LINE_WEATHER = 2, LINE_EVENT = 3 }

    private var mAccent as Number = 0xFF6A3D;
    private var mRingMode as Number = RING_DAY;
    private var mFocus as Number = FOCUS_BATTERY;
    private var mLine as Number = LINE_SMART;
    private var mSeconds as Boolean = false;
    private var mAodRing as Boolean = true;
    // DateFormat setting (FaceKit.DATE_*), resolved against the watch when drawn
    private var mDateSetting as Number = FaceKit.DATE_WATCH;

    private var mScale as Float = 1.0f;
    private var mAwake as Boolean = true;
    private var mEditMode as Boolean;
    private var mData as FaceData = new FaceData();

    private var mFontHours as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontMinutes as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontValue as FontType = Graphics.FONT_SMALL;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontDateBold as FontType = Graphics.FONT_XTINY;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;
    private var mFontLine as FontType = Graphics.FONT_XTINY;
    private var mFontSeconds as FontType = Graphics.FONT_TINY;

    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        mEditMode = editMode;
        loadSettings();
    }

    function onLayout(dc as Dc) as Void {
        mScale = dc.getWidth() / FaceKit.DESIGN;
        try {
            mFontHours = WatchUi.loadResource(Rez.Fonts.Hours) as FontResource;
            mFontMinutes = WatchUi.loadResource(Rez.Fonts.Minutes) as FontResource;
            mFontValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
            mFontDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
            mFontDateBold = WatchUi.loadResource(Rez.Fonts.DateBold) as FontResource;
            mFontLabel = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
            mFontLine = WatchUi.loadResource(Rez.Fonts.Line) as FontResource;
            mFontSeconds = WatchUi.loadResource(Rez.Fonts.Seconds) as FontResource;
        } catch (e) {
            // System fonts stay in place
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

    // ---- Settings -----------------------------------------------------------

    function loadSettings() as Void {
        mAccent = FaceKit.prop("AccentColor", 0xFF6A3D);
        mRingMode = FaceKit.prop("RingMode", RING_DAY);
        mFocus = FaceKit.prop("Focus", FOCUS_BATTERY);
        mLine = FaceKit.prop("BottomLine", LINE_SMART);
        mSeconds = FaceKit.prop("ShowSeconds", 0) == 1;
        mAodRing = FaceKit.prop("AodRing", 1) == 1;
        mDateSetting = FaceKit.prop("DateFormat", FaceKit.DATE_WATCH);
        var editor = FaceEditor.settingsFor(null);
        if (editor == null) {
            return;
        }
        if (mEditMode) {
            applyEditor(editor);
            return;
        }
        // Outside the editor, whichever of phone and editor changed the setting last wins
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
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var nowH = clock.hour + clock.min / 60.0f;

        if ((!mAwake || FaceDemo.FORCE_AOD) && !mEditMode && FaceKit.burnInProtection()) {
            drawAlwaysOn(dc, clock, now, nowH);
            return;
        }

        if (mRingMode == RING_ACTIVITY) {
            drawActivityRings(dc, 0.0f, 0.0f, false);
        } else {
            drawDayDial(dc, nowH, 0.0f, 0.0f, false);
        }
        drawDate(dc, now, 0.0f, 0.0f, false);
        drawTime(dc, clock, mFontHours, INK, INK, 0.0f, 0.0f, mSeconds && mAwake);
        drawFocus(dc);
        drawBars(dc);
        drawBottomLine(dc, nowH);
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
        dc.setColor(AOD_TICK, Graphics.COLOR_TRANSPARENT);
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
            dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
            dc.drawCircle(cx, cy, r);
        }

        var sleep = mData.sleepTime;
        var wake = mData.wakeTime;
        if (sleep != null && wake != null) {
            dc.setColor(aod ? 0x2A2F66 : FaceKit.mix(SLEEP, 0x000000, 0.85f), Graphics.COLOR_TRANSPARENT);
            FaceKit.roundArc(dc, cx, cy, r, hourDeg(sleep), hourDeg(wake), w);
        }

        var rise = mData.sunrise;
        var set = mData.sunset;
        if (rise != null && set != null) {
            var doneTo = nowH < rise ? rise : (nowH > set ? set : nowH);
            if (doneTo < set) {
                dc.setColor(aod ? 0x3A2D16 : SUN_SOFT, Graphics.COLOR_TRANSPARENT);
                FaceKit.roundArc(dc, cx, cy, r, hourDeg(doneTo), hourDeg(set), w);
            }
            if (doneTo > rise) {
                dc.setColor(aod ? 0x7A5B22 : SUN, Graphics.COLOR_TRANSPARENT);
                FaceKit.roundArc(dc, cx, cy, r, hourDeg(rise), hourDeg(doneTo), w);
            }
        }

        if (!aod) {
            for (var h = 0; h < 24; h++) {
                var major = h % 6 == 0;
                dc.setColor(major ? DIM : TRACK, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(FaceKit.penWidth(major ? 3.0f : 2.0f, mScale));
                var a = FaceKit.clockPoint(hourDeg(h.toFloat()), major ? 176 : 184);
                var b = FaceKit.clockPoint(hourDeg(h.toFloat()), 192);
                dc.drawLine(cx + a[0] * mScale, cy + a[1] * mScale, cx + b[0] * mScale, cy + b[1] * mScale);
            }
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
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
            dc.setColor(0x9A9790, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(nx, ny, 4 * mScale);
            return;
        }
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.5f, mScale));
        dc.drawCircle(nx, ny, 14 * mScale);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(nx, ny, 10 * mScale);
        dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
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
        var colors = [mAccent, SUN, SLEEP];
        for (var i = 0; i < 3; i++) {
            var r = ((aod ? RING_R - 4 : RING_R) - i * ACT_STEP) * mScale;
            if (!aod) {
                dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(aod ? AOD_MINUTES : DIM, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(hoursColor, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, left, y, hoursFont, hours, track, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(minutesColor, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, left + wH + gap, y, mFontMinutes, minutes, track, Graphics.TEXT_JUSTIFY_LEFT);
        if (seconds) {
            dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
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
        }
        var bb = mData.bodyBattery;
        return ["BODY BATTERY", bb != null ? bb.toString() : "--", "/100", bb != null ? FaceKit.clamp01(bb / 100.0f) : null];
    }

    // Label, value and unit on one baseline, centred.
    private function drawFocus(dc as Dc) as Void {
        var m = metric(mFocus);
        var track = 2.0f * mScale;
        var gap = 8.0f * mScale;
        var wL = FaceKit.trackedWidth(dc, mFontLabel, m[0], track);
        var wV = dc.getTextWidthInPixels(m[1], mFontValue);
        var wU = m[2].length() > 0 ? gap + dc.getTextWidthInPixels(m[2], mFontLabel) : 0;
        var left = C * mScale - (wL + gap + wV + wU) / 2;
        var base = FOCUS_BASE * mScale;
        var labelY = base - Graphics.getFontAscent(mFontLabel) / 2.0f;
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, left, labelY, mFontLabel, m[0], track, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + wL + gap, base - Graphics.getFontAscent(mFontValue), mFontValue, m[1], Graphics.TEXT_JUSTIFY_LEFT);
        if (m[2].length() > 0) {
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + wL + gap + wV + gap, base - Graphics.getFontAscent(mFontLabel), mFontLabel, m[2],
                Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // Four mini bars (battery, steps, heart, stress); the focus metric's in the accent.
    private function drawBars(dc as Dc) as Void {
        var w = 40.0f * mScale;
        var h = 5.0f * mScale;
        var gap = 8.0f * mScale;
        var left = C * mScale - (4 * w + 3 * gap) / 2;
        var top = BARS_Y * mScale - h / 2;
        for (var i = 0; i < 4; i++) {
            var x = left + i * (w + gap);
            dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, top, w, h, h / 2);
            var f = metric(i)[3];
            if (f != null && f > 0.0f) {
                var fw = w * f;
                dc.setColor(i == mFocus ? mAccent : DIM, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x, top, fw < h ? h : fw, h, h / 2);
            }
        }
    }

    // Icon + text: sunset countdown, weather, or the next calendar event.
    private function drawBottomLine(dc as Dc, nowH as Float) as Void {
        var line = bottomLine(nowH);
        if (line == null) {
            return;
        }
        var icon = 16.0f * mScale;
        var gap = 8.0f * mScale;
        var wT = dc.getTextWidthInPixels(line[1] as String, mFontLine);
        var left = C * mScale - (icon + gap + wT) / 2;
        var y = LINE_Y * mScale;
        drawIcon(dc, line[0] as Number, left, y - icon / 2, icon);
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + icon + gap, y, mFontLine, line[1] as String, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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
        dc.setColor(SUN, Graphics.COLOR_TRANSPARENT);
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
