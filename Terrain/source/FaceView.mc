import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Terrain: the last 24 hours of heart rate drawn as a mountain ridge (now at the right),
// snow down to a line set by stress, a flag on the ridge at step-goal progress, and the
// sun crossing the sky from sunrise to sunset (a moon at night). Geometry follows the
// canvas mockup (Terrain.dc.html, 454 px); every coordinate is in design pixels.
class FaceView extends FaceCoreView {

    private const C = FaceKit.C;

    private const SKY = 0x0C1220;
    private const FAR_RANGE = 0x161F31;
    private const RIDGE_FILL = 0x24324A;
    private const RIDGE_LINE = 0x9FB2CC;
    private const SNOW = 0xEEF2F7;
    private const SUN_PATH = 0x2A3550;
    private const SUN = 0xF2B544;
    private const MOON = 0xC9D3E2;
    private const INK = 0xF3F1EC;
    private const DIM = 0x8D9AB0;
    private const NOW_LABEL = 0xC9D3E2;

    // Ridge: 24 hourly maxima plus the current reading, from x 24 to 398 (the mockup's
    // 416 put the now-point on the screen edge), heart rate 45..160 bpm to y 392..222.
    private const X0 = 24.0f;
    private const X1 = 398.0f;
    private const HR_LOW = 45.0f;
    private const HR_HIGH = 160.0f;
    private const Y_LOW = 392.0f;
    private const Y_SPAN = 170.0f;

    private const DATE_Y = 80.5f;
    private const TIME_Y = 139.5f;
    private const SUN_LINE_Y = 192.5f;

    private const FAR = [[0, 338], [58, 306], [112, 322], [172, 284], [232, 310], [292, 270], [350, 300],
        [402, 284], [454, 304], [454, 454], [0, 454]];

    // DateFormat setting (FaceFormat.DATE_*), resolved against the watch when drawn

    private var mFontTime as FontType = Graphics.FONT_NUMBER_HOT;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontSmall as FontType = Graphics.FONT_XTINY;
    private var mFontFlag as FontType = Graphics.FONT_XTINY;

    // Ridge samples (design px) and the heart rate values they were built from
    private var mRidge as Array<[Float, Float]> = [] as Array<[Float, Float]>;
    private var mValues as Array<Float> = [] as Array<Float>;
    private var mRidgeKey as String = "";

    function initialize(editMode as Boolean) {
        FaceCoreView.initialize(editMode, 0xFF6A3D, FaceFormat.DATE_WATCH);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = FaceKit.loadFonts([Rez.Fonts.Time, Rez.Fonts.Date, Rez.Fonts.Small, Rez.Fonts.Flag] as Array<ResourceId>,
            [Graphics.FONT_NUMBER_HOT, Graphics.FONT_XTINY, Graphics.FONT_XTINY, Graphics.FONT_XTINY] as Array<FontType>);
        mFontTime = f[0];
        mFontDate = f[1];
        mFontSmall = f[2];
        mFontFlag = f[3];
    }

    // ---- Drawing --------------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        mData.refresh();
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var nowH = clock.hour + clock.min / 60.0f;
        buildRidge();

        if (alwaysOn()) {
            drawAlwaysOn(dc, clock);
            return;
        }

        dc.setColor(SKY, SKY);
        dc.clear();
        drawSky(dc, nowH);

        dc.setColor(FAR_RANGE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(scaled(FAR as Array<Array<Numeric>>, 0.0f, 0.0f));

        // Ridge, snow above the stress line, outline
        dc.setColor(RIDGE_FILL, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(ridgeFill());
        var stress = mData.stress;
        drawSnow(dc, 250.0f + (stress != null ? stress : 25) * 1.5f);
        dc.setColor(RIDGE_LINE, Graphics.COLOR_TRANSPARENT);
        drawRidgeLine(dc, 0.0f, 0.0f, 2.0f);

        drawFlag(dc);
        drawNow(dc);
        drawText(dc, now, nowH, INK, DIM, 0.0f, 0.0f, true);
    }

    // Always-On: the ridge outline and the time, dimmed and moved every minute (aodShift).
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        var dx = shift[0].toFloat();
        var dy = shift[1].toFloat();
        dc.setColor(0x4A5872, Graphics.COLOR_TRANSPARENT);
        drawRidgeLine(dc, dx, dy, 2.0f);
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        drawText(dc, now, 0.0f, 0xB4BCC8, 0x5E6A80, dx, dy, false);
    }

    // Date, time and the sunset / sunrise line, centred near the top.
    private function drawText(dc as Dc, now as Gregorian.Info, nowH as Float, ink as Number, dim as Number,
            dx as Float, dy as Float, sunLine as Boolean) as Void {
        var cx = (C + dx) * mScale;
        dc.setColor(dim, Graphics.COLOR_TRANSPARENT);
        var date = FaceKit.dateText(now, FaceKit.dateFormat(mDateSetting));
        FaceKit.drawTracked(dc, cx, (DATE_Y + dy) * mScale, mFontDate, date, 3.0f * mScale, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        var time = FaceKit.hourText(now.hour as Number) + ":" + FaceKit.twoDigits(now.min as Number);
        FaceKit.drawTracked(dc, cx, (TIME_Y + dy) * mScale, mFontTime, time, -3.0f * mScale, Graphics.TEXT_JUSTIFY_CENTER);

        if (!sunLine) {
            return;
        }
        var rise = mData.sunrise;
        var set = mData.sunset;
        if (rise == null || set == null) {
            return;
        }
        var text = (nowH >= rise && nowH < set) ? "sunset " + FaceKit.clockText(set) : "sunrise " + FaceKit.clockText(rise);
        dc.setColor(dim, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (SUN_LINE_Y + dy) * mScale, mFontSmall, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Dotted sun path from horizon to horizon; the sun on it by the time of day, or the
    // moon on the same path through the night.
    private function drawSky(dc as Dc, nowH as Float) as Void {
        dc.setColor(SUN_PATH, Graphics.COLOR_TRANSPARENT);
        var dots = 44;
        for (var k = 0; k <= dots; k++) {
            var p = skyPoint(k.toFloat() / dots);
            dc.fillCircle(p[0] * mScale, p[1] * mScale, 1.0f * mScale);
        }
        var rise = mData.sunrise;
        var set = mData.sunset;
        if (rise == null || set == null) {
            return;
        }
        if (nowH >= rise && nowH < set) {
            var s = skyPoint((nowH - rise) / (set - rise));
            dc.setColor(FaceKit.mix(SUN, SKY, 0.16f), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(s[0] * mScale, s[1] * mScale, 24 * mScale);
            dc.setColor(SUN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(s[0] * mScale, s[1] * mScale, 13 * mScale);
        } else {
            var night = 24.0f - set + rise;
            var since = nowH >= set ? nowH - set : nowH + 24.0f - set;
            var m = skyPoint(since / night);
            dc.setColor(MOON, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(m[0] * mScale, m[1] * mScale, 11 * mScale);
            dc.setColor(SKY, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((m[0] + 5) * mScale, (m[1] - 4) * mScale, 10 * mScale);
        }
    }

    // Point on the sky arc at 0..1 (design px).
    private function skyPoint(q as Float) as [Float, Float] {
        q = FaceKit.clamp01(q);
        return [60.0f + q * 334.0f, (300.0f - Math.sin(Math.PI * q) * 150.0f).toFloat()];
    }

    // ---- Ridge ------------------------------------------------------------------

    // 25 heart rate points (24 hourly maxima, then now), gaps filled from the neighbours,
    // smoothed with quadratic curves through the midpoints as in the mockup.
    private function buildRidge() as Void {
        var hours = mData.hrHours();
        var current = mData.heartRate();
        var raw = new Array<Number or Null>[25];
        for (var i = 0; i < 24; i++) {
            raw[i] = hours[i];
        }
        raw[24] = current != null ? current : hours[23];
        var key = raw.toString();
        if (key.equals(mRidgeKey)) {
            return;
        }
        mRidgeKey = key;

        var values = new Array<Float>[25];
        var last = null;
        for (var i = 0; i < 25; i++) {
            if (raw[i] != null) {
                last = (raw[i] as Number).toFloat();
            }
            values[i] = last;
        }
        // Leading gaps take the first reading; no readings at all lie flat at 60
        var first = null;
        for (var i = 0; i < 25 && first == null; i++) {
            first = values[i];
        }
        for (var i = 0; i < 25; i++) {
            if (values[i] == null) {
                values[i] = first != null ? first : 60.0f;
            }
        }
        // Interior gaps: linear between the readings either side
        var i = 0;
        while (i < 25) {
            if (raw[i] == null) {
                var j = i;
                while (j < 25 && raw[j] == null) {
                    j++;
                }
                if (i > 0 && j < 25) {
                    var a = values[i - 1] as Float;
                    var b = (raw[j] as Number).toFloat();
                    for (var k = i; k < j; k++) {
                        values[k] = a + (b - a) * (k - i + 1) / (j - i + 1);
                    }
                }
                i = j;
            } else {
                i++;
            }
        }
        mValues = values as Array<Float>;

        var pts = new Array<[Float, Float]>[25];
        for (var n = 0; n < 25; n++) {
            pts[n] = [xAt(n.toFloat()), yAt(mValues[n])];
        }
        var ridge = [[0.0f, pts[0][1]], pts[0]] as Array<[Float, Float]>;
        var start = pts[0];
        for (var n = 1; n < 25; n++) {
            var p = pts[n - 1];
            var q = pts[n];
            var end = [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2] as [Float, Float];
            // Quadratic from start via p to end, sampled at t = 0.5 and 1
            ridge.add([0.25f * start[0] + 0.5f * p[0] + 0.25f * end[0], 0.25f * start[1] + 0.5f * p[1] + 0.25f * end[1]]);
            ridge.add(end);
            start = end;
        }
        var lastPt = pts[24];
        ridge.add(lastPt);
        ridge.add([FaceKit.DESIGN, lastPt[1] + 4]);
        mRidge = ridge;
    }

    private function xAt(i as Float) as Float {
        return X0 + i * (X1 - X0) / 24;
    }

    private function yAt(v as Float) as Float {
        var f = (v - HR_LOW) / (HR_HIGH - HR_LOW);
        f = f < -0.05f ? -0.05f : (f > 1.0f ? 1.0f : f);
        return Y_LOW - f * Y_SPAN;
    }

    // Ridge fill polygon in px (ridge samples, closed along the bottom).
    private function ridgeFill() as Array<[Float, Float]> {
        var pts = new Array<[Float, Float]>[mRidge.size() + 2];
        for (var i = 0; i < mRidge.size(); i++) {
            pts[i] = [mRidge[i][0] * mScale, mRidge[i][1] * mScale];
        }
        pts[mRidge.size()] = [FaceKit.DESIGN * mScale, FaceKit.DESIGN * mScale];
        pts[mRidge.size() + 1] = [0.0f, FaceKit.DESIGN * mScale];
        return pts;
    }

    // Snow: every part of the ridge above the snow line, as one polygon per peak.
    private function drawSnow(dc as Dc, snowY as Float) as Void {
        dc.setColor(SNOW, Graphics.COLOR_TRANSPARENT);
        var cap = [] as Array<[Float, Float]>;
        for (var i = 0; i < mRidge.size(); i++) {
            var p = mRidge[i];
            var above = p[1] < snowY;
            if (i > 0) {
                var prev = mRidge[i - 1];
                var prevAbove = prev[1] < snowY;
                if (above != prevAbove) {
                    var t = (snowY - prev[1]) / (p[1] - prev[1]);
                    cap.add([(prev[0] + (p[0] - prev[0]) * t) * mScale, snowY * mScale]);
                    if (!above) {
                        if (cap.size() >= 3) {
                            dc.fillPolygon(cap);
                        }
                        cap = [] as Array<[Float, Float]>;
                    }
                }
            }
            if (above) {
                cap.add([p[0] * mScale, p[1] * mScale]);
            }
        }
        if (cap.size() >= 3) {
            dc.fillPolygon(cap);
        }
    }

    private function drawRidgeLine(dc as Dc, dx as Float, dy as Float, width as Float) as Void {
        dc.setPenWidth(FaceKit.penWidth(width, mScale));
        for (var i = 1; i < mRidge.size(); i++) {
            var a = mRidge[i - 1];
            var b = mRidge[i];
            dc.drawLine((a[0] + dx) * mScale, (a[1] + dy) * mScale, (b[0] + dx) * mScale, (b[1] + dy) * mScale);
        }
        dc.setPenWidth(1);
    }

    // Flag on the ridge at step-goal progress (0 = 24 h ago, 1 = now), percentage beside it.
    private function drawFlag(dc as Dc) as Void {
        var goal = FaceData.fraction(mData.steps, mData.stepGoal);
        if (goal == null) {
            return;
        }
        var gi = goal * 24;
        var i0 = Math.floor(gi < 23.999f ? gi : 23.999f).toNumber();
        var t = gi - i0;
        var fx = xAt(gi);
        var fy = yAt(mValues[i0] + (mValues[i0 + 1] - mValues[i0]) * t) - 2;
        var top = fy - 30;
        dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        dc.drawLine(fx * mScale, fy * mScale, fx * mScale, top * mScale);
        dc.setPenWidth(1);
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[fx * mScale, top * mScale], [(fx + 20) * mScale, (top + 7) * mScale], [fx * mScale, (top + 14) * mScale]]);
        // Percentage left of the pole, or right of the flag near the left edge
        var pct = Math.round(goal * 100).toNumber().toString() + "%";
        if (fx < 110) {
            dc.drawText((fx + 26) * mScale, (top + 6) * mScale, mFontFlag, pct, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText((fx - 6) * mScale, (top + 6) * mScale, mFontFlag, pct, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // The current heart rate at the ridge's right end.
    private function drawNow(dc as Dc) as Void {
        var x = xAt(24.0f);
        var y = yAt(mValues[24]);
        dc.setColor(SKY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x * mScale, y * mScale, 7 * mScale);
        dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x * mScale, y * mScale, 5 * mScale);
        var hr = mData.heartRate();
        if (hr != null) {
            dc.setColor(NOW_LABEL, Graphics.COLOR_TRANSPARENT);
            // Inside the mountain, under and left of the dot (clear of the outline and the screen edge)
            dc.drawText((x - 10) * mScale, (y + 18) * mScale, mFontSmall, hr.toString() + " bpm",
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function scaled(pts as Array<Array<Numeric>>, dx as Float, dy as Float) as Array<[Float, Float]> {
        var out = new Array<[Float, Float]>[pts.size()];
        for (var i = 0; i < pts.size(); i++) {
            out[i] = [(pts[i][0] + dx) * mScale, (pts[i][1] + dy) * mScale];
        }
        return out;
    }
}
