import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Bloom: the day's balance as one soft five-lobed shape. Each lobe swells with its
// metric (energy, steps, sleep, calm, recovery); the lowest one's value is highlighted.
// Three nested fills, the time in the middle. Geometry follows the canvas mockup
// (Bloom.dc.html, 454 px); every coordinate is in design pixels.
class FaceView extends WatchUi.WatchFace {

    private const C = FaceKit.C;

    private const RING = 0x2C2A2B;
    private const SPOKE = 0x1E1D1E;
    private const INK = 0xF3F1EC;
    private const KEY = 0x8E8B85;
    private const LOW = 0xFF8A3D;            // default highlight (lowest value)
    private const TIME_DARK = 0x140A0E;

    // Shape: radius = BASE + SPAN x (Gaussian-weighted mix of the five values)
    private const BASE = 52.0f;
    private const SPAN = 113.0f;
    private const SIGMA = 0.42f;
    private const SAMPLES = 60;                 // fillPolygon takes at most 64 points
    private const LABEL_R = 192.0f;
    // Cap centres relative to a label's centre: the mockup stacks value (14 px, line 18.2)
    // over key (10 px, line 13) with a 1 px gap, centred on the label point.
    private const VALUE_DY = -6.6f;
    private const KEY_DY = 9.9f;
    private const GUIDE_R = 165.0f;

    // Cap centres of the time (60 px, line-height 1) and date (12 px, 4 px below), centred
    // as one block on the dial like the mockup's flex column.
    private const TIME_Y = 217.0f;
    private const DATE_Y = 259.3f;
    // Letter-spacing in CSS also follows the last glyph, so centred tracked text sits half
    // a spacing off centre: the time 1 px right, the date 1 px left, the keys 0.75 px left.
    private const TIME_TRACK = -2.0f;
    private const DATE_TRACK = 2.0f;
    private const KEY_TRACK = 1.5f;

    private const KEYS = ["ENERGY", "STEPS", "SLEEP", "CALM", "RECOVERY"] as Array<String>;
    // Palettes: [outer, mid, core]. Rose, Sage, Sky are the mockup's; the others (and a
    // custom colour) take mid / core as the outer colour at 65 % / 30 % over white.
    private const PALETTES = [[0xE86A8A, 0xF29BB0, 0xFBD3DD], [0x5FB585, 0x9ED6B1, 0xD3EEDB],
        [0x5B9BF0, 0x93BEF6, 0xCFE1FB], [0xF07A5A, 0xF5A994, 0xFAD7CE], [0xE0A83A, 0xEBC67F, 0xF6E5C4],
        [0x9C7CE8, 0xBFAAF0, 0xE1D8F8], [0x3FBDB5, 0x82D4CF, 0xC5EBE9], [0xB4B0A8, 0xCECCC6, 0xE8E7E5]];
    private const MID_W = 0.65f;
    private const CORE_W = 0.30f;

    private var mPalette as Number = 0;
    // The fills in use [outer, mid, core] and the highlight colour
    private var mColors as Array<Number> = PALETTES[0] as Array<Number>;
    private var mLow as Number = LOW;
    // Colours from the watch face editor (edited there last), else the phone settings
    private var mFromEditor as Boolean = false;
    // DateFormat setting (FaceKit.DATE_*), resolved against the watch when drawn
    private var mDateSetting as Number = FaceKit.DATE_WATCH;
    private var mScale as Float = 1.0f;
    private var mAwake as Boolean = true;
    private var mEditMode as Boolean;
    private var mData as FaceData = new FaceData();

    private var mFontTime as FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var mFontTimeAod as FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontValue as FontType = Graphics.FONT_XTINY;
    private var mFontKey as FontType = Graphics.FONT_XTINY;

    // Shape outline (design px, unit scale) and labels, rebuilt when the values change
    private var mOutline as Array<[Float, Float]> = [] as Array<[Float, Float]>;
    private var mValues as Array<Float> = [0.5f, 0.5f, 0.5f, 0.5f, 0.5f] as Array<Float>;
    private var mTexts as Array<String> = ["--", "--", "--", "--", "--"] as Array<String>;
    private var mLowest as Number = -1;
    private var mKey as String = "";

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
            mFontValue = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
            mFontKey = WatchUi.loadResource(Rez.Fonts.Key) as FontResource;
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

    // Colours come from wherever they were changed last: the phone settings or the watch
    // face editor. The editor always reports a style and accent (its defaults until the
    // user edits), so applying it on top would hide the phone settings on the fr970.
    // A custom colour (phone only) wins over the palette.
    function loadSettings() as Void {
        mPalette = FaceKit.prop("Palette", 0);
        mLow = FaceKit.prop("Highlight", LOW);
        mDateSetting = FaceKit.prop("DateFormat", FaceKit.DATE_WATCH);
        var editor = FaceEditor.settingsFor(null);
        mFromEditor = editor != null && colorsFromEditor();
        if (mFromEditor) {
            editorColors(editor as Application.WatchFaceConfig.Settings);
        }
        applyColors();
    }

    // New phone settings (BloomApp.onSettingsChanged): they win from now on.
    function phoneSettingsChanged() as Void {
        setColorsFromEditor(false);
        loadSettings();
    }

    // Edited on the watch (FaceEditorDelegate): the editor wins from now on.
    function applyEditor(settings as Application.WatchFaceConfig.Settings) as Void {
        setColorsFromEditor(true);
        mFromEditor = true;
        editorColors(settings);
        applyColors();
    }

    // Watch face editor: style 1-8 = the palettes, accent colour = highlight.
    private function editorColors(settings as Application.WatchFaceConfig.Settings) as Void {
        var style = settings.styleId;
        if (style != null && style >= 1 && style <= PALETTES.size()) {
            mPalette = style - 1;
        }
        var accent = settings.accentColor;
        if (accent != null && accent.color instanceof Number) {
            mLow = accent.color as Number;
        }
    }

    private function colorsFromEditor() as Boolean {
        try {
            var v = Application.Storage.getValue("ColorsFromEditor");
            return v instanceof Boolean && v;
        } catch (e) {
            return false;
        }
    }

    private function setColorsFromEditor(on as Boolean) as Void {
        try {
            Application.Storage.setValue("ColorsFromEditor", on);
        } catch (e) {
        }
    }

    private function applyColors() as Void {
        if (mPalette < 0 || mPalette >= PALETTES.size()) {
            mPalette = 0;
        }
        mColors = PALETTES[mPalette] as Array<Number>;
        var custom = null;
        try {
            custom = mFromEditor ? null : hexColor(Application.Properties.getValue("CustomColor"));
        } catch (e) {
        }
        if (custom != null) {
            mColors = [custom, FaceKit.mix(custom, 0xFFFFFF, MID_W), FaceKit.mix(custom, 0xFFFFFF, CORE_W)];
        }
        // Demo builds (store screenshots) pin the colours
        if (FaceDemo.PALETTE >= 0) {
            mColors = PALETTES[FaceDemo.PALETTE] as Array<Number>;
        }
        if (FaceDemo.HIGHLIGHT >= 0) {
            mLow = FaceDemo.HIGHLIGHT;
        }
    }

    // "E86A8A", "#E86A8A" or "0xE86A8A" as a colour; null for anything else (empty = off).
    private function hexColor(value as Application.Properties.ValueType or Null) as Number or Null {
        if (!(value instanceof String)) {
            return null;
        }
        var s = value.toUpper();
        if (s.find("#") == 0) {
            s = s.substring(1, s.length()) as String;
        } else if (s.find("0X") == 0) {
            s = s.substring(2, s.length()) as String;
        }
        if (s.length() != 6) {
            return null;
        }
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if ("0123456789ABCDEF".find(chars[i].toString()) == null) {
                return null;
            }
        }
        return s.toNumberWithBase(16);
    }

    // ---- Drawing --------------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (mData.refresh() || mOutline.size() == 0) {
            readValues();
        }
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        FaceDemo.time(clock, now);
        var time = FaceKit.hourText(clock.hour) + ":" + FaceKit.twoDigits(clock.min);

        if ((!mAwake || FaceDemo.FORCE_AOD) && !mEditMode && FaceKit.burnInProtection()) {
            drawAlwaysOn(dc, clock, time);
            return;
        }

        // Dashed guide circle (3 px dashes, 6 px gaps, from 3 o'clock clockwise) and the
        // five spokes
        solid(dc, RING);
        dc.setPenWidth(FaceKit.penWidth(1.5f, mScale));
        var circumference = 2 * Math.PI * GUIDE_R;
        for (var s = 0.0f; s < circumference; s += 9.0f) {
            var end = s + 3.0f < circumference ? s + 3.0f : circumference;
            var a = FaceKit.clockPoint(90.0f + Math.toDegrees(s / GUIDE_R), GUIDE_R);
            var b = FaceKit.clockPoint(90.0f + Math.toDegrees(end / GUIDE_R), GUIDE_R);
            dc.drawLine((C + a[0]) * mScale, (C + a[1]) * mScale, (C + b[0]) * mScale, (C + b[1]) * mScale);
        }
        dc.setColor(SPOKE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(1.5f, mScale));
        for (var i = 0; i < 5; i++) {
            var a = FaceKit.clockPoint(i * 72, 40);
            var b = FaceKit.clockPoint(i * 72, 165);
            dc.drawLine((C + a[0]) * mScale, (C + a[1]) * mScale, (C + b[0]) * mScale, (C + b[1]) * mScale);
        }
        dc.setPenWidth(1);

        // The three fills and the dark time and date, as in the mockup. If the shape is
        // too small to hold the text: light text first (shows wherever the shape doesn't
        // reach), then each fill followed by the same fill again inside the text box with
        // a texture of that colour plus dark text, so the text stays readable on black.
        var date = dateText(now);
        var box = textBox(dc, time, date);
        var covered = covers(box);
        if (!covered) {
            dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
            drawCentre(dc, time, date, 0.0f, 0.0f);
        }
        var palette = mColors;
        var scales = [1.0f, 0.78f, 0.56f];
        for (var i = 0; i < 3; i++) {
            var pts = shape(scales[i], 0.0f, 0.0f);
            solid(dc, palette[i]);
            dc.fillPolygon(pts);
            if (!covered) {
                fillDarkText(dc, pts, box, palette[i], time, date);
            }
        }
        if (covered) {
            dc.setColor(TIME_DARK, Graphics.COLOR_TRANSPARENT);
            drawCentre(dc, time, date, 0.0f, 0.0f);
        }
        solid(dc, INK);

        // Labels around the shape: value over key; the lowest value in orange
        for (var i = 0; i < 5; i++) {
            var p = FaceKit.clockPoint(i * 72, LABEL_R);
            var x = (C + p[0]) * mScale;
            var y = (C + p[1]) * mScale;
            dc.setColor(i == mLowest ? mLow : INK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y + VALUE_DY * mScale, mFontValue, mTexts[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(KEY, Graphics.COLOR_TRANSPARENT);
            FaceKit.drawTracked(dc, x - KEY_TRACK / 2 * mScale, y + KEY_DY * mScale, mFontKey, KEYS[i],
                KEY_TRACK * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        }

    }

    // Time and date centred, shifted by (-ox, -oy) px (to draw into the text bitmap).
    private function drawCentre(dc as Dc, time as String, date as String, ox as Float, oy as Float) as Void {
        FaceKit.drawTracked(dc, (C - TIME_TRACK / 2) * mScale - ox, TIME_Y * mScale - oy, mFontTime, time,
            TIME_TRACK * mScale, Graphics.TEXT_JUSTIFY_CENTER);
        FaceKit.drawTracked(dc, (C - DATE_TRACK / 2) * mScale - ox, DATE_Y * mScale - oy, mFontDate, date,
            DATE_TRACK * mScale, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Screen box [x, y, w, h] (px) around the time and date.
    private function textBox(dc as Dc, time as String, date as String) as [Number, Number, Number, Number] {
        var w = FaceKit.trackedWidth(dc, mFontTime, time, TIME_TRACK * mScale);
        var wd = FaceKit.trackedWidth(dc, mFontDate, date, DATE_TRACK * mScale);
        if (wd > w) {
            w = wd;
        }
        var left = Math.floor(C * mScale - w / 2 - 5).toNumber();
        var top = Math.floor(TIME_Y * mScale - dc.getFontHeight(mFontTime) / 2.0f - 4).toNumber();
        var bottom = Math.ceil(DATE_Y * mScale + dc.getFontHeight(mFontDate) / 2.0f + 4).toNumber();
        return [left, top, Math.ceil(w + 10).toNumber(), bottom - top];
    }

    private var mCoverKey as String = "";
    private var mCovered as Boolean = false;

    // Whether the outer fill covers the whole text box (px), checked every 4 design px along
    // the box's edges; the shape is star-shaped around the centre, so the edges suffice.
    private function covers(box as [Number, Number, Number, Number]) as Boolean {
        var key = mKey + box.toString();
        if (key.equals(mCoverKey)) {
            return mCovered;
        }
        mCoverKey = key;
        var x0 = box[0] / mScale - C;
        var y0 = box[1] / mScale - C;
        var x1 = (box[0] + box[2]) / mScale - C;
        var y1 = (box[1] + box[3]) / mScale - C;
        var corners = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
        for (var c = 0; c < 4; c++) {
            var a = corners[c];
            var b = corners[(c + 1) % 4];
            var len = Math.sqrt((b[0] - a[0]) * (b[0] - a[0]) + (b[1] - a[1]) * (b[1] - a[1]));
            var steps = Math.ceil(len / 4.0f).toNumber();
            for (var k = 0; k < steps; k++) {
                var x = a[0] + (b[0] - a[0]) * k / steps;
                var y = a[1] + (b[1] - a[1]) * k / steps;
                if (Math.sqrt(x * x + y * y) > radius(Math.atan2(y, x)) - 1.0f) {
                    mCovered = false;
                    return false;
                }
            }
        }
        mCovered = true;
        return true;
    }

    // Fills the polygon again, only inside the text box, with a texture of the fill
    // colour and the dark text. Without texture fills (or memory) the text stays light.
    private function fillDarkText(dc as Dc, pts as Array<[Float, Float]>, box as [Number, Number, Number, Number],
            color as Number, time as String, date as String) as Void {
        if (!(dc has :setFill)) {
            return;
        }
        var bitmap = textBitmap(box[2], box[3]);
        if (bitmap == null) {
            return;
        }
        var bdc = bitmap.getDc();
        bdc.setAntiAlias(true);
        bdc.setColor(color, color);
        bdc.clear();
        bdc.setColor(TIME_DARK, Graphics.COLOR_TRANSPARENT);
        drawCentre(bdc, time, date, box[0].toFloat(), box[1].toFloat());

        // The texture's offset maps to the polygon's bounding-box top-left corner
        var minX = pts[0][0];
        var minY = pts[0][1];
        for (var i = 1; i < pts.size(); i++) {
            if (pts[i][0] < minX) {
                minX = pts[i][0];
            }
            if (pts[i][1] < minY) {
                minY = pts[i][1];
            }
        }
        var offX = Math.floor(minX).toNumber() - box[0];
        var offY = Math.floor(minY).toNumber() - box[1];
        offX = ((offX % box[2]) + box[2]) % box[2];
        offY = ((offY % box[3]) + box[3]) % box[3];
        dc.setClip(box[0], box[1], box[2], box[3]);
        dc.setFill(new Graphics.BitmapTexture({:bitmap => bitmap, :offsetX => offX, :offsetY => offY}));
        dc.fillPolygon(pts);
        dc.clearClip();
        solid(dc, color);
    }

    private var mTextBitmap as BufferedBitmapReference or Null;
    private var mTextSize as Number = 0;

    // The text-box bitmap, created once per size; null without graphics memory.
    private function textBitmap(w as Number, h as Number) as BufferedBitmap or Null {
        var size = w * 10000 + h;
        if (mTextBitmap == null || size != mTextSize) {
            mTextSize = size;
            try {
                mTextBitmap = Graphics.createBufferedBitmap({:width => w, :height => h});
            } catch (e) {
                mTextBitmap = null;
            }
        }
        var ref = mTextBitmap;
        return ref != null ? ref.get() as BufferedBitmap or Null : null;
    }

    // Plain colour for fills and text (a texture fill, once set, wins over setColor).
    private function solid(dc as Dc, color as Number) as Void {
        if (dc has :setFill) {
            dc.setFill(0xFF000000 | color);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    }

    // Always-On: the shape's outline and a light time, moved a few pixels a minute.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, time as String) as Void {
        var shifts = [[0, 0], [3, 2], [-2, 3], [2, -3], [-3, -1], [1, 3], [-1, -3], [3, -1]];
        var shift = shifts[clock.min % shifts.size()] as Array<Number>;
        var dx = shift[0].toFloat();
        var dy = shift[1].toFloat();
        var pts = shape(1.0f, dx, dy);
        dc.setColor(FaceKit.mix(mColors[0], 0x000000, 0.55f), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(FaceKit.penWidth(2.0f, mScale));
        for (var i = 0; i < pts.size(); i++) {
            var a = pts[i];
            var b = pts[(i + 1) % pts.size()];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
        dc.setPenWidth(1);
        dc.setColor(0xB9B6B0, Graphics.COLOR_TRANSPARENT);
        FaceKit.drawTracked(dc, (C + dx - TIME_TRACK / 2) * mScale, (TIME_Y + dy) * mScale, mFontTimeAod, time,
            TIME_TRACK * mScale, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Shape --------------------------------------------------------------------

    // The five values (0..1, 0.5 when unknown) and their texts.
    private function readValues() as Void {
        var bb = mData.bodyBattery;
        var steps = mData.steps;
        var stepF = FaceData.fraction(steps, mData.stepGoal);
        var sleep = mData.sleepScore();
        var stress = mData.stress;
        var recovery = mData.recoveryHours;

        var values = [
            bb != null ? FaceKit.clamp01(bb / 100.0f) : null,
            stepF,
            sleep != null ? FaceKit.clamp01(sleep / 100.0f) : null,
            stress != null ? FaceKit.clamp01(1.0f - stress / 100.0f) : null,
            // Recovery: fully recovered at 0 h left, nothing at 72 h or more
            recovery != null ? FaceKit.clamp01(1.0f - recovery / 72.0f) : null
        ];
        var texts = [
            bb != null ? bb.toString() : "--",
            steps != null ? stepsText(steps) : "--",
            sleep != null ? sleep.toString() : "--",
            stress != null ? (100 - stress).toString() : "--",
            values[4] != null ? Math.round((values[4] as Float) * 100).toNumber().toString() + "%" : "--"
        ];
        var key = values.toString();
        mTexts = texts as Array<String>;
        if (key.equals(mKey)) {
            return;
        }
        mKey = key;

        mLowest = -1;
        var lowest = 2.0f;
        for (var i = 0; i < 5; i++) {
            var v = values[i];
            mValues[i] = v != null ? v as Float : 0.5f;
            if (v != null && (v as Float) < lowest) {
                lowest = v as Float;
                mLowest = i;
            }
        }

        var outline = new Array<[Float, Float]>[SAMPLES];
        for (var k = 0; k < SAMPLES; k++) {
            var a = -Math.PI / 2 + k * 2 * Math.PI / SAMPLES;
            var r = radius(a);
            outline[k] = [(r * Math.cos(a)).toFloat(), (r * Math.sin(a)).toFloat()];
        }
        mOutline = outline;
    }

    // Radius at angle a (radians, 0 = 3 o'clock, clockwise on screen).
    private function radius(a as Float or Double) as Float {
        var ws = 0.0f;
        var acc = 0.0f;
        for (var i = 0; i < 5; i++) {
            var th = -Math.PI / 2 + i * 2 * Math.PI / 5;
            var d = (a - th).abs();
            while (d > 2 * Math.PI) {
                d -= 2 * Math.PI;
            }
            if (d > Math.PI) {
                d = 2 * Math.PI - d;
            }
            var w = Math.pow(Math.E, -(d * d) / (2 * SIGMA * SIGMA)).toFloat();
            ws += w;
            acc += w * mValues[i];
        }
        return BASE + SPAN * acc / ws;
    }

    private function shape(scale as Float, dx as Float, dy as Float) as Array<[Float, Float]> {
        var pts = new Array<[Float, Float]>[mOutline.size()];
        for (var k = 0; k < mOutline.size(); k++) {
            pts[k] = [(C + dx + mOutline[k][0] * scale) * mScale, (C + dy + mOutline[k][1] * scale) * mScale];
        }
        return pts;
    }

    // "7.4k" above 1,000 steps.
    private function stepsText(steps as Number) as String {
        if (steps < 1000) {
            return steps.toString();
        }
        return (steps / 1000.0f).format("%.1f") + "k";
    }

    // "SAT 10" (the mockup's short date, for the named format) or "SAT 10-10-2026".
    private function dateText(now as Gregorian.Info) as String {
        var format = FaceKit.dateFormat(mDateSetting);
        if (format == FaceKit.DATE_NAMED) {
            return FaceKit.dayName(now.day_of_week as Number) + " " + (now.day as Number).toString();
        }
        return FaceKit.dateText(now, format);
    }
}
