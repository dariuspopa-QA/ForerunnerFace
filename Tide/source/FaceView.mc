import Toybox.Application;
import Toybox.Complications;
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
// Watches without texture fills draw the dark digits clipped to strips under the wave.
class FaceView extends FaceCoreView {

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

    // Editor data slots (resources/configs/watchface.xml) and their tap boxes (design px)
    private const SLOT_TAG = 1;
    private const SLOT_LINE = 2;
    private const TAG_BOX_W = 130.0f;
    private const LINE_BOX_W = 260.0f;
    private const SLOT_BOX_H = 36.0f;

    // Bubble spots: [x, depth 0..1 between the surface and the bottom, radius]
    private const SPOTS = [[168, 0.30f, 5.0f], [205, 0.62f, 3.5f], [248, 0.45f, 6.5f], [292, 0.78f, 4.0f],
        [228, 0.88f, 3.0f], [318, 0.35f, 5.5f], [140, 0.70f, 3.5f], [262, 0.15f, 4.5f], [186, 0.95f, 3.0f]];

    // DateFormat setting (FaceFormat.DATE_*), resolved against the watch when drawn

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
        FaceCoreView.initialize(editMode, 0x3FD0C9, FaceFormat.DATE_WATCH);
        loadSettings();
    }

    function loadFonts() as Void {
        var f = loadFontSet([Rez.Fonts.Time, Rez.Fonts.TimeAod, Rez.Fonts.Date, Rez.Fonts.Tag] as Array<ResourceId>,
            [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_XTINY, Graphics.FONT_XTINY] as Array<FontType>);
        mFontTime = f[0];
        mFontTimeAod = f[1];
        mFontDate = f[2];
        mFontTag = f[3];
        mWaterKey = "";
    }

    // New colours: the cached water texture is rebuilt.
    function loadPhoneSettings() as Void {
        mWaterKey = "";
    }

    function applyEditor(settings as Application.WatchFaceConfig.Settings) as Void {
        FaceCoreView.applyEditor(settings);
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

        var surface = surfaceY();
        var stress = mData.stress;
        var amp = 3.0f + (stress != null ? stress : 25) * 0.14f;

        if (alwaysOn()) {
            drawAlwaysOn(dc, clock, hours, minutes, surface, amp);
            return;
        }

        dc.setColor(ink(GROUND), GROUND);
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
        dc.setColor(ink(LIGHT), Graphics.COLOR_TRANSPARENT);
        drawTime(dc, hours, minutes, mFontTime, 0.0f, 0.0f);

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
            // No texture fills (watches without enhanced graphics, e.g. Forerunner 165 / 255,
            // vivoactive 5) or no graphics memory: plain water, bubbles drawn on it, and the
            // dark digits clipped to the water in narrow vertical strips.
            solid(dc, mAccent);
            dc.fillPolygon(front);
            drawBubbles(dc, surface, steps);
            dc.setColor(ink(GROUND), Graphics.COLOR_TRANSPARENT);
            drawUnderwater(dc, front, hours, minutes);
        }

        // Date at the top; the tag at the surface on the right (Body Battery); the line at the
        // bottom (steps). The tag and the line are the editor's data slots; the one the
        // editor is previewing is drawn by the editor.
        dc.setColor(ink(DATE_COLOR), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, DATE_Y * mScale, mFontDate, dateText(now), 3.0f * mScale,
            Graphics.TEXT_JUSTIFY_CENTER);
        if (mEditingSlot != SLOT_TAG) {
            drawTag(dc, surface);
        }
        if (mEditingSlot != SLOT_LINE) {
            drawLine(dc, surface);
        }
    }

    // ---- Data slots (on-watch editor) --------------------------------------------
    // 1 = the tag riding the surface (Body Battery by default), 2 = the line at the bottom
    // (steps by default). The water level and the bubbles stay Body Battery and steps
    // whatever the slots show.

    function slots() as Array<Number> {
        return [SLOT_TAG, SLOT_LINE] as Array<Number>;
    }

    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        var surface = surfaceY();
        if (slot == SLOT_TAG) {
            var y = tagY(surface);
            var right = tagRight(y);
            return box(right - TAG_BOX_W, y - SLOT_BOX_H / 2, TAG_BOX_W, SLOT_BOX_H);
        }
        if (slot == SLOT_LINE) {
            return box(C - LINE_BOX_W / 2, lineY(surface) - SLOT_BOX_H / 2, LINE_BOX_W, SLOT_BOX_H);
        }
        return null;
    }

    function drawSlot(dc as Dc, slot as Number) as Void {
        var surface = surfaceY();
        if (slot == SLOT_TAG) {
            drawTag(dc, surface);
        } else if (slot == SLOT_LINE) {
            drawLine(dc, surface);
        }
    }

    // The tag: Body Battery as a bare number (the mockup), or the picked field.
    private function drawTag(dc as Dc, surface as Float) as Void {
        var bb = mData.bodyBattery;
        var text = slotLine(SLOT_TAG, Complications.COMPLICATION_TYPE_BODY_BATTERY, bb != null ? bb.toString() : null);
        if (text == null) {
            return;
        }
        var y = tagY(surface);
        dc.setColor(ink(mAccent), Graphics.COLOR_TRANSPARENT);
        dc.drawText(tagRight(y) * mScale, y * mScale, mFontTag, text,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // The line: "7,412 STEPS" (the mockup), or the picked field as "VALUE LABEL". In the
    // water when it reaches the bottom line, else just above the surface.
    private function drawLine(dc as Dc, surface as Float) as Void {
        var steps = mData.steps;
        var text = slotLine(SLOT_LINE, Complications.COMPLICATION_TYPE_STEPS,
            steps != null ? FaceKit.thousands(steps) + " STEPS" : null);
        if (text == null) {
            return;
        }
        var under = surface < STEPS_Y - 16;
        dc.setColor(ink(under ? GROUND : mAccent), Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, C * mScale, lineY(surface) * mScale, mFontTag, text,
            fitTracking(dc, mFontTag, text, 1.0f * mScale, LINE_BOX_W * mScale), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // A slot's text: the face's own (own, null = nothing) while the slot holds the face's
    // own field or none, else the picked field's "VALUE LABEL" ("--" until it has a value).
    function slotLine(slot as Number, ownType as Number, own as String or Null) as String or Null {
        var type = slotType(slot);
        if (type == null || type == ownType) {
            return own;
        }
        var t = slotText(slot);
        if (t == null) {
            return FaceFormat.NO_VALUE;
        }
        return (t[1].length() > 0 ? t[0] + " " + t[1] : t[0]).toUpper();
    }

    // The water surface (design px) for the Body Battery level (5-100; half full without it).
    private function surfaceY() as Float {
        var bb = mData.bodyBattery;
        var level = bb != null ? (bb < 5 ? 5 : (bb > 100 ? 100 : bb)) : 50;
        return 454.0f - 454.0f * level / 100;
    }

    // The tag's centre line just above the surface, kept below the date, and above the
    // line when the water is so low that the line rides the surface too; its right end
    // inside the round screen.
    private function tagY(surface as Float) as Float {
        var y = surface - 20;
        var line = lineY(surface);
        if (line != STEPS_Y && y > line - SLOT_BOX_H - 4) {
            y = line - SLOT_BOX_H - 4;
        }
        return y < 80 ? 80.0f : y;
    }

    private function tagRight(y as Float) as Float {
        var edge = C + Math.sqrt(C * C - (y - C) * (y - C)).toFloat() - 24;
        return edge < 404 ? edge : 404.0f;
    }

    private function lineY(surface as Float) as Float {
        return surface < STEPS_Y - 16 ? STEPS_Y : surface - 34;
    }

    // [x, y, w, h] in px of a box in design px.
    private function box(x as Float, y as Float, w as Float, h as Float) as [Number, Number, Number, Number] {
        return [Math.round(x * mScale).toNumber(), Math.round(y * mScale).toNumber(),
            Math.round(w * mScale).toNumber(), Math.round(h * mScale).toNumber()];
    }

    // Always-On: only the water line and thin light digits, moved every minute (aodShift).
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, hours as String, minutes as String,
            surface as Float, amp as Float) as Void {
        dc.setColor(ink(Graphics.COLOR_BLACK), Graphics.COLOR_BLACK);
        dc.clear();
        var shift = aodShift(clock.min);
        var pts = wave(surface + shift[1], amp, 0.0f);
        dc.setColor(FaceKit.mix(mAccent, 0x000000, 0.6f), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        for (var i = 1; i < WAVE_POINTS; i++) {
            var a = pts[i - 1];
            var b = pts[i];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
        dc.setPenWidth(1);
        dc.setColor(ink(0xA9B8BC), Graphics.COLOR_TRANSPARENT);
        drawTime(dc, hours, minutes, mFontTimeAod, shift[0].toFloat(), shift[1].toFloat());
    }

    // Plain colour for fills and text (a texture fill, once set, wins over setColor).
    private function solid(dc as Dc, color as Number) as Void {
        if (dc has :setFill) {
            dc.setFill(0xFF000000 | color);
        }
        dc.setColor(ink(color), Graphics.COLOR_TRANSPARENT);
    }

    private function drawTime(dc as Dc, hours as String, minutes as String, font as FontType, dx as Float, dy as Float) as Void {
        var track = TIME_TRACKING * mScale;
        FaceKit.drawTracked(dc, (C + dx) * mScale, (HOURS_Y + dy) * mScale, font, hours, track, Graphics.TEXT_JUSTIFY_CENTER);
        FaceKit.drawTracked(dc, (C + dx) * mScale, (MINUTES_Y + dy) * mScale, font, minutes, track, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The underwater layer at screen size: water colour, bubbles, dark digits. Cached
    // until the time, surface, steps or colour change; null without graphics memory.
    private function waterLayer(dc as Dc, hours as String, minutes as String, surface as Float,
            steps as Number or Null) as BufferedBitmapReference or Null {
        if (!(dc has :setFill)) {
            return null;
        }
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
        bdc.setColor(ink(mAccent), mAccent);
        bdc.clear();

        drawBubbles(bdc, surface, steps);
        bdc.setColor(ink(GROUND), Graphics.COLOR_TRANSPARENT);
        drawTime(bdc, hours, minutes, mFontTime, 0.0f, 0.0f);
        return mWater;
    }

    // One bubble per 1,000 steps (up to nine), between just under the surface and the bottom.
    private function drawBubbles(dc as Dc, surface as Float, steps as Number or Null) as Void {
        var bubbles = steps != null ? steps / 1000 : 0;
        if (bubbles > SPOTS.size()) {
            bubbles = SPOTS.size();
        }
        var top = surface + 26;
        var bottom = 392.0f;
        if (bottom <= top) {
            return;
        }
        dc.setColor(FaceKit.mix(BUBBLE, mAccent, 0.75f), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        for (var i = 0; i < bubbles; i++) {
            var s = SPOTS[i] as Array<Numeric>;
            var cy = top + (bottom - top) * (s[1] as Float);
            dc.drawCircle((s[0] as Number) * mScale, cy * mScale, (s[2] as Float) * mScale);
        }
        dc.setPenWidth(1);
    }

    // Clip rectangles [x, y, w, h] (px) covering the water under the front wave, and the
    // wave they were made for
    private var mStrips as Array<Array<Number>> = [] as Array<Array<Number>>;
    private var mStripsKey as String = "";

    // The digits in the current colour, clipped to the water below the front wave: one
    // rectangle below the wave's lowest point, then strips of STRIP px between its highest
    // and lowest point, each starting at the lowest point of the wave over that strip (so
    // no dark ink shows above the surface).
    private function drawUnderwater(dc as Dc, front as Array<[Float, Float]>, hours as String, minutes as String) as Void {
        var key = front[0].toString() + front[WAVE_POINTS / 2].toString() + front[WAVE_POINTS - 1].toString();
        if (!key.equals(mStripsKey)) {
            mStripsKey = key;
            mStrips = waterStrips(dc, front);
        }
        var h = dc.getFontHeight(mFontTime) / 2.0f;
        for (var i = 0; i < mStrips.size(); i++) {
            var r = mStrips[i];
            var top = r[1];
            var bottom = r[1] + r[3];
            dc.setClip(r[0], r[1], r[2], r[3]);
            var track = TIME_TRACKING * mScale;
            if (top < (HOURS_Y * mScale + h) && bottom > (HOURS_Y * mScale - h)) {
                FaceKit.drawTracked(dc, C * mScale, HOURS_Y * mScale, mFontTime, hours, track, Graphics.TEXT_JUSTIFY_CENTER);
            }
            if (top < (MINUTES_Y * mScale + h) && bottom > (MINUTES_Y * mScale - h)) {
                FaceKit.drawTracked(dc, C * mScale, MINUTES_Y * mScale, mFontTime, minutes, track, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        dc.clearClip();
    }

    private function waterStrips(dc as Dc, front as Array<[Float, Float]>) as Array<Array<Number>> {
        var w = dc.getWidth();
        var bottom = dc.getHeight();
        var lo = 0.0f;
        var hi = bottom.toFloat();
        for (var i = 0; i < WAVE_POINTS; i++) {
            var y = front[i][1];
            lo = y > lo ? y : lo;
            hi = y < hi ? y : hi;
        }
        var deep = Math.ceil(lo).toNumber();
        var strips = [[0, deep, w, bottom - deep]] as Array<Array<Number>>;
        // Only where the digits can be (12 to 88 % across)
        var step = Math.round(2 * mScale).toNumber();
        step = step < 2 ? 2 : step;
        var x0 = Math.floor(w * 0.12f).toNumber();
        var x1 = Math.ceil(w * 0.88f).toNumber();
        var dx = front[1][0] - front[0][0];
        for (var x = x0; x < x1; x += step) {
            // the wave's lowest point (largest y) over [x, x + step]
            var a = Math.floor(x / dx).toNumber();
            var b = Math.ceil((x + step) / dx).toNumber();
            var y = 0.0f;
            for (var k = a; k <= b && k < WAVE_POINTS; k++) {
                y = front[k][1] > y ? front[k][1] : y;
            }
            var top = Math.ceil(y).toNumber();
            if (top < deep) {
                strips.add([x, top, step, deep - top]);
            }
        }
        return strips;
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
