import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Tide: the water level is Body Battery, the waves get rougher with stress, the back
// wave drifts faster with heart rate, and every 1,000 steps adds a bubble. The time is
// huge; where the water covers it the digits turn dark. Geometry follows the canvas
// mockup (Tide.dc.html, 454 px); every coordinate is in design pixels.
//
// The underwater part is one textured polygon: a bitmap holding the water colour,
// bubbles and dark digits fills the front wave's shape (Dc.setFill with a BitmapTexture).
class FaceView extends WatchUi.WatchFace {

    private const C = FaceKit.C;

    private const GROUND = 0x06121A;
    private const LIGHT = 0xEAF6F5;
    private const BUBBLE = 0xEAFBFA;
    private const DATE_COLOR = 0x8FA6AD;

    private const HOURS_Y = 168.0f;
    private const MINUTES_Y = 298.0f;
    private const TIME_TRACKING = -6.0f;
    private const DATE_Y = 45.0f;
    private const STEPS_Y = 409.0f;
    private const WAVELENGTH = 113.5f;
    private const WAVE_POINTS = 62;          // fillPolygon takes at most 64 points

    // Bubble spots: [x, depth 0..1 between the surface and the bottom, radius]
    private const SPOTS = [[168, 0.30f, 5.0f], [205, 0.62f, 3.5f], [248, 0.45f, 6.5f], [292, 0.78f, 4.0f],
        [228, 0.88f, 3.0f], [318, 0.35f, 5.5f], [140, 0.70f, 3.5f], [262, 0.15f, 4.5f], [186, 0.95f, 3.0f]];

    private var mAccent as Number = 0x3FD0C9;
    // DateFormat setting (FaceKit.DATE_*), resolved against the watch when drawn
    private var mDateSetting as Number = FaceKit.DATE_WATCH;
    private var mScale as Float = 1.0f;
    private var mAwake as Boolean = true;
    private var mEditMode as Boolean;
    private var mData as FaceData = new FaceData();

    private var mFontTime as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontTimeAod as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontTag as FontType = Graphics.FONT_XTINY;

    // Underwater layer and what it was drawn for (rebuilt when any of it changes)
    private var mWater as BufferedBitmapReference or Null;
    private var mWaterKey as String = "";

    // Back-wave drift phase (radians), advanced on every update by heart rate
    private var mDrift as Float = 0.0f;

    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        mEditMode = editMode;
        loadSettings();
    }

    function onLayout(dc as Dc) as Void {
        mScale = dc.getWidth() / FaceKit.DESIGN;
        try {
            mFontTime = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
            mFontTimeAod = WatchUi.loadResource(Rez.Fonts.TimeAod) as FontResource;
            mFontDate = WatchUi.loadResource(Rez.Fonts.Date) as FontResource;
            mFontTag = WatchUi.loadResource(Rez.Fonts.Tag) as FontResource;
        } catch (e) {
        }
        mWaterKey = "";
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
        mAccent = FaceKit.prop("AccentColor", 0x3FD0C9);
        mDateSetting = FaceKit.prop("DateFormat", FaceKit.DATE_WATCH);
        var editor = FaceEditor.settingsFor(null);
        if (editor != null) {
            applyEditor(editor);
        }
        mWaterKey = "";
    }

    function applyEditor(settings as Application.WatchFaceConfig.Settings) as Void {
        var accent = settings.accentColor;
        if (accent != null && accent.color instanceof Number) {
            mAccent = accent.color as Number;
        }
        mWaterKey = "";
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

        var bb = mData.bodyBattery;
        var level = bb != null ? (bb < 5 ? 5 : (bb > 100 ? 100 : bb)) : 50;
        var surface = 454.0f - 454.0f * level / 100;
        var stress = mData.stress;
        var amp = 3.0f + (stress != null ? stress : 25) * 0.14f;

        if ((!mAwake || FaceDemo.FORCE_AOD) && !mEditMode && FaceKit.burnInProtection()) {
            drawAlwaysOn(dc, clock, hours, minutes, surface, amp);
            return;
        }

        dc.setColor(GROUND, GROUND);
        dc.clear();

        // Back wave, drifting: a quarter of the mockup's speed per one-second update
        var hr = mData.heartRate();
        mDrift += 2 * Math.PI * (hr != null && hr > 40 ? hr : 60) / 240.0f * 0.25f;
        if (mDrift > 2 * Math.PI) {
            mDrift -= 2 * Math.PI;
        }
        solid(dc, FaceKit.mix(mAccent, GROUND, 0.38f));
        dc.fillPolygon(wave(surface - 7, amp * 1.3f, 1.7f + mDrift));

        // Light digits, then the front wave filled with the underwater layer
        dc.setColor(LIGHT, Graphics.COLOR_TRANSPARENT);
        drawTime(dc, hours, minutes, mFontTime, 0.0f);

        var steps = mData.steps;
        var front = wave(surface, amp, 0.0f);
        var water = waterLayer(dc, hours, minutes, surface, steps);
        if (water != null && (dc has :setFill)) {
            // The texture's offset is mapped to the polygon's top-left corner
            var top = front[0][1];
            for (var i = 1; i < front.size(); i++) {
                if (front[i][1] < top) {
                    top = front[i][1];
                }
            }
            dc.setFill(new Graphics.BitmapTexture({:bitmap => water, :offsetX => 0, :offsetY => Math.floor(top).toNumber()}));
            dc.fillPolygon(front);
            solid(dc, mAccent);
        } else {
            // No graphics memory: plain water, digits stay light
            solid(dc, mAccent);
            dc.fillPolygon(front);
        }

        // Date at the top; the Body Battery tag at the surface on the right; steps at the bottom
        dc.setColor(DATE_COLOR, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, DATE_Y * mScale, mFontDate, dateText(now), 3.0f * mScale,
            Graphics.TEXT_JUSTIFY_CENTER);
        if (bb != null) {
            var tagY = surface - 20 < 80 ? 80.0f : surface - 20;
            var edge = C + Math.sqrt(C * C - (tagY - C) * (tagY - C)).toFloat() - 24;
            dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
            dc.drawText((edge < 404 ? edge : 404) * mScale, tagY * mScale, mFontTag, bb.toString(),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        if (steps != null) {
            // In the water when it reaches the bottom line, else just above the surface
            var under = surface < STEPS_Y - 16;
            dc.setColor(under ? GROUND : mAccent, Graphics.COLOR_TRANSPARENT);
            FaceKit.drawTracked(dc, C * mScale, (under ? STEPS_Y : surface - 34) * mScale, mFontTag, FaceKit.thousands(steps) + " STEPS",
                1.0f * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Always-On: only the water line and thin light digits, moved a few pixels a minute.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hours as String, minutes as String,
            surface as Float, amp as Float) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var shifts = [[0, 0], [3, 2], [-2, 3], [2, -3], [-3, -1], [1, 3], [-1, -3], [3, -1]];
        var shift = shifts[clock.min % shifts.size()] as Array<Number>;
        var pts = wave(surface + shift[1], amp, 0.0f);
        dc.setColor(FaceKit.mix(mAccent, 0x000000, 0.6f), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        for (var i = 1; i < WAVE_POINTS; i++) {
            var a = pts[i - 1];
            var b = pts[i];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
        dc.setPenWidth(1);
        dc.setColor(0xA9B8BC, Graphics.COLOR_TRANSPARENT);
        drawTime(dc, hours, minutes, mFontTimeAod, shift[0].toFloat());
    }

    // Plain colour for fills and text (a texture fill, once set, wins over setColor).
    private function solid(dc as Dc, color as Number) as Void {
        if (dc has :setFill) {
            dc.setFill(0xFF000000 | color);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    }

    private function drawTime(dc as Dc, hours as String, minutes as String, font as FontType, dx as Float) as Void {
        var track = TIME_TRACKING * mScale;
        FaceKit.drawTracked(dc, (C + dx) * mScale, HOURS_Y * mScale, font, hours, track, Graphics.TEXT_JUSTIFY_CENTER);
        FaceKit.drawTracked(dc, (C + dx) * mScale, MINUTES_Y * mScale, font, minutes, track, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The underwater layer at screen size: water colour, bubbles, dark digits. Cached
    // until the time, surface, steps or colour change; null without graphics memory.
    private function waterLayer(dc as Dc, hours as String, minutes as String, surface as Float,
            steps as Number or Null) as BufferedBitmapReference or Null {
        var bubbles = steps != null ? steps / 1000 : 0;
        if (bubbles > SPOTS.size()) {
            bubbles = SPOTS.size();
        }
        var key = hours + minutes + "/" + surface.toNumber() + "/" + bubbles + "/" + mAccent;
        if (key.equals(mWaterKey) && mWater != null) {
            return mWater;
        }
        mWaterKey = key;
        if (mWater == null) {
            try {
                mWater = Graphics.createBufferedBitmap({:width => dc.getWidth(), :height => dc.getHeight()});
            } catch (e) {
                mWater = null;
                return null;
            }
        }
        var bitmap = (mWater as BufferedBitmapReference).get();
        if (bitmap == null) {
            mWater = null;
            return null;
        }
        var bdc = (bitmap as BufferedBitmap).getDc();
        bdc.setAntiAlias(true);
        bdc.setColor(mAccent, mAccent);
        bdc.clear();

        // Bubbles between just under the surface and the bottom
        var top = surface + 26;
        var bottom = 392.0f;
        if (bottom > top) {
            bdc.setColor(FaceKit.mix(BUBBLE, mAccent, 0.75f), Graphics.COLOR_TRANSPARENT);
            bdc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
            for (var i = 0; i < bubbles; i++) {
                var s = SPOTS[i] as Array<Numeric>;
                var cy = top + (bottom - top) * (s[1] as Float);
                bdc.drawCircle((s[0] as Number) * mScale, cy * mScale, (s[2] as Float) * mScale);
            }
            bdc.setPenWidth(1);
        }

        bdc.setColor(GROUND, Graphics.COLOR_TRANSPARENT);
        drawTime(bdc, hours, minutes, mFontTime, 0.0f);
        return mWater;
    }

    // Wave polygon in px: the surface across the screen, closed along the bottom.
    private function wave(level as Float, amp as Float, phase as Float) as Array<[Float, Float]> {
        var pts = new Array<[Float, Float]>[WAVE_POINTS + 2];
        var step = FaceKit.DESIGN / (WAVE_POINTS - 1);
        var k = 2 * Math.PI / WAVELENGTH;
        for (var i = 0; i < WAVE_POINTS; i++) {
            var x = i * step;
            var y = level + amp * Math.sin(x * k + phase) + amp * 0.35f * Math.sin(x * k / 0.37f);
            pts[i] = [x * mScale, y.toFloat() * mScale];
        }
        pts[WAVE_POINTS] = [FaceKit.DESIGN * mScale, FaceKit.DESIGN * mScale];
        pts[WAVE_POINTS + 1] = [0.0f, FaceKit.DESIGN * mScale];
        return pts;
    }

    private function dateText(now as Gregorian.Info) as String {
        return FaceKit.dateText(now, FaceKit.dateFormat(mDateSetting));
    }
}
