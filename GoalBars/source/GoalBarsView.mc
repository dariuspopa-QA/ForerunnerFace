import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.WatchUi;

// ---------- Colors ----------
const ACCENTS = [0xB6F24A, 0x5AC8FA, 0xFF9F0A, 0xFF6B9D, 0xF2F2F7];
const C_WHITE   = 0xFFFFFF;
const C_GRAY    = 0x8E8E93;
const C_SOFT    = 0xC7C7CC;
const C_LABEL   = 0x6E6E73;
const C_OFF     = 0x3A3A3C;
const C_TICK    = 0x1C1C1E;
const C_TICK_HI = 0x3A3A3C;
const C_CARD_BG = 0x0E1013;
const C_HATCH   = 0x15181C;
const C_CARD_EDGE = 0x1F2328;
const C_ARC_BG  = 0x1F2226;
const C_ALARM   = 0xFFB340;
const C_LOW     = 0xFF453A;
const C_DND     = 0xA78BFA;
const C_AOD     = 0x6E6E73;
const C_AOD_DIM = 0x3A3A3C;
const C_AOD_MIN = 0x4A4A4E;   // always-on minutes: gray, never the accent
const C_AOD_TICK = 0x2C2C2E;
const AOD_SHIFT = 0.044;      // largest FaceKit.aodShift offset (10 of 227 design px), fraction of radius
const AOD_TIME_K = 0.86;      // always-on time size vs awake (fewer lit pixels)
const C_BG_GRAY = 0xB0B0B8;

// One fixed color per metric (Apple system palette: vivid but coordinated),
// so a metric is recognizable by color alone in any bar slot. Each bar's
// empty track is a dim tint of its own color - the activity-ring trick that
// makes an empty bar look designed rather than like a placeholder.
const BAR_COLORS = [0x34C759, 0x64D2FF, 0x5E5CE6, 0xFF375F, 0xFFD60A, 0xBF5AF2, 0xFF9F0A];
const TRACK_TINT = 0.20;
// Active calories goal choices (CaloriesGoal setting; Garmin has no calorie goal API)
const KCAL_GOALS = [300, 500, 750, 1000];

const BG_LEVELS = [0.14, 0.24, 0.36];

// ---------- Layout (fractions of screen radius from center; y = v-center) ----------
// Both layouts share one grammar, taken from Garmin's native faces: equal-size
// two-tone time, data grouped in a textured card, date/status centered on top,
// heart rate centered at the bottom, watch battery as an arc on the left bezel.
const STATUS_Y    = -0.774;
const DATE_Y      = -0.649;
const HR_Y        =  0.779;

// Stacked (default): hours over minutes right-aligned to a gutter, card on the right.
const S_TIME_R    = -0.019;
const S_HOUR_Y    = -0.226;
const S_MIN_Y     =  0.399;
const S_TIME_SIZE =  0.635;
const S_CARD      = [0.067, -0.462, 0.721, 1.087];  // x, y, w, h
const S_BAR_W     =  0.096;
const S_BAR_GAP   =  0.067;
const S_VAL_SIZE  =  0.077;

// Classic: hours:minutes centered, full-width card below.
const C_TIME_Y    = -0.293;
const C_TIME_GAP  =  0.060;
const C_TIME_SIZE =  0.558;
const C_CARD      = [-0.625, 0.010, 1.250, 0.673];
const C_BAR_W     =  0.125;
const C_BAR_GAP   =  0.163;
const C_VAL_SIZE  =  0.082;

const CARD_RADIUS =  0.110;
const CARD_PAD_T  =  0.090;  // card top to bar top
const CARD_PAD_B  =  0.205;  // bar bottom to card bottom (room for values)
const CARD_VAL_B  =  0.105;  // value center above card bottom

const DATE_SIZE   =  0.093;
const STATUS_SIZE =  0.072;
const HR_SIZE     =  0.092;

// Garmin's vector fonts render ~13% smaller than the same nominal size
// elsewhere; sizes above are true type sizes and get scaled by this.
const FONT_K = 1.15;

// DateFormat setting (as in ApexFace): follow the watch (order from its distance units),
// "MON 28 SEP", "MON 28-09-2026", "MON 09-28-2026", or no date
const DF_WATCH = 0;
const DF_NAMED = 1;
const DF_DMY   = 2;
const DF_MDY   = 3;
const DF_OFF   = 4;

class GoalBarsView extends WatchUi.WatchFace {

    // Settings
    private var _accent = 0xB6F24A;
    private var _layout = 0;
    private var _bgStyle = 0;
    private var _bgIntensity = 0;
    private var _bgColorMode = 0;
    private var _clockMode = 0;
    private var _timeWeight = 0;
    private var _dateFormat = 0;
    private var _kcalGoal = 500;
    private var _bars = [0, 1, 4, 2];
    private var _showPace = true;
    private var _showNotif = true;
    private var _showAlarms = true;
    private var _showDnd = true;
    private var _aodDate = true;

    // State
    private var _awake = true;
    private var _fontsReady = false;
    private var _timeFont = Graphics.FONT_NUMBER_HOT;
    private var _aodFont = Graphics.FONT_NUMBER_MILD;
    private var _hrFont = Graphics.FONT_SMALL;
    private var _dateFont = Graphics.FONT_TINY;
    private var _valFont = Graphics.FONT_SMALL;
    private var _labFont = Graphics.FONT_XTINY;
    private var _statusFont = Graphics.FONT_XTINY;
    private var _ticks = null;
    private var _mip = false;

    // Cached baked-image background (see bgImage())
    private var _bgImage = null;
    private var _bgImageSymbol = null;

    // Native watch face editor (see EditorConfig.mc)
    private var _editMode = false;     // running inside the editor
    private var _editingSlot = null;   // slot being previewed, hidden from the face
    private var _bottomId = null;      // complication shown in the bottom slot (null = heart rate)
    private var _r = 0.0;
    private var _cx = 0;
    private var _cy = 0;

    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        _editMode = editMode;
        loadSettings(false);
    }

    // ---------- Settings ----------

    private function prop(key as String, def) {
        var v = null;
        try {
            v = Application.Properties.getValue(key);
        } catch (e) {
            v = null;
        }
        return (v == null) ? def : v;
    }

    private function clampIdx(v, max, def) {
        return (v == null || v < 0 || v >= max) ? def : v;
    }

    // fromPhone: the settings just changed in the Connect IQ app (see phoneWins()).
    function loadSettings(fromPhone as Boolean) as Void {
        _accent      = ACCENTS[clampIdx(prop("AccentColor", 0), ACCENTS.size(), 0)];
        _layout      = clampIdx(prop("Layout", 0), 2, 0);
        _bgStyle     = clampIdx(prop("BgStyle", 0), 9, 0);
        _bgIntensity = clampIdx(prop("BgIntensity", 0), BG_LEVELS.size(), 0);
        _bgColorMode = prop("BgColor", 0);
        _clockMode   = prop("ClockMode", 0);
        _timeWeight  = clampIdx(prop("TimeWeight", 0), 2, 0);
        _dateFormat  = prop("DateFormat", 0);
        _kcalGoal    = KCAL_GOALS[clampIdx(prop("CaloriesGoal", 1), KCAL_GOALS.size(), 1)];
        _bars = [
            clampIdx(prop("Bar1", 0), BAR_COLORS.size(), 0),
            clampIdx(prop("Bar2", 1), BAR_COLORS.size(), 1),
            clampIdx(prop("Bar3", 4), BAR_COLORS.size(), 4),
            clampIdx(prop("Bar4", 2), BAR_COLORS.size(), 2)
        ];
        _showPace    = prop("ShowPace", true);
        _showNotif   = prop("ShowNotifications", true);
        _showAlarms  = prop("ShowAlarms", true);
        _showDnd     = prop("ShowDnd", true);
        _aodDate     = prop("AodShowDate", true);
        _fontsReady  = false;
        var s = editorSettings(null);
        applyEditorWins(s, null, phoneWins(s, fromPhone));
    }

    // On watches with the on-watch editor (fr970) both it and the Connect IQ app set
    // the style, accent and bars; whichever was changed last wins. A phone change
    // remembers the editor's state at that moment, and the phone settings hold until
    // the editor's choices differ from it (the face was edited on the watch).
    private function phoneWins(s, fromPhone as Boolean) as Boolean {
        if (s == null || _editMode) {
            return false;
        }
        var key = editorKey(s);
        try {
            if (fromPhone) {
                Application.Storage.setValue("PhoneOverEditor", key);
                return true;
            }
            var pinned = Application.Storage.getValue("PhoneOverEditor");
            return (pinned instanceof String) && pinned.equals(key);
        } catch (e) {
            return fromPhone;
        }
    }

    private function editorKey(s) as String {
        var key = "" + s.styleId + "/" + ((s.accentColor != null) ? s.accentColor.color : null);
        var refs = s.complicationSettings;
        if (refs != null) {
            for (var i = 0; i < refs.size(); i++) {
                key += "/" + refs[i].uniqueIdentifier + ":" + complicationType(refs[i].complicationId);
            }
        }
        return key;
    }

    // ---------- Native watch face editor ----------
    // Slots: 1-4 = the bars, 5 = the bottom data field.

    // From the on-watch editor (FaceCore/slots/EditorConfig.mc): the editor's choices win.
    function applyEditor(s, editedType) as Void {
        applyEditorWins(s, editedType, false);
    }

    // phoneWins: keep the phone's style, accent and bars; only the bottom field
    // (which has no phone setting) is taken from the editor.
    function applyEditorWins(s, editedType, phoneWins as Boolean) as Void {
        if (s == null) {
            return;
        }
        if (s.styleId != null && !phoneWins) {
            _layout = (s.styleId == 2) ? 1 : 0;
        }
        if (s.accentColor != null && s.accentColor.color != null && !phoneWins) {
            _accent = s.accentColor.color;
        }
        var refs = s.complicationSettings;
        if (refs != null) {
            for (var i = 0; i < refs.size(); i++) {
                var slot = refs[i].uniqueIdentifier;
                var type = complicationType(refs[i].complicationId);
                if (slot != null && slot >= 1 && slot <= 4 && !phoneWins) {
                    var kind = kindForComplication(type);
                    if (kind != null) {
                        _bars[slot - 1] = kind;
                    }
                } else if (slot == 5) {
                    _bottomId = (type == null || type == Complications.COMPLICATION_TYPE_HEART_RATE)
                        ? null : refs[i].complicationId;
                }
            }
        }
        if (editedType == null || editedType != WatchUi.WATCH_FACE_CONFIG_TYPE_COMPLICATION) {
            _editingSlot = null;
        }
        subscribeBottom();
        _fontsReady = false;
        WatchUi.requestUpdate();
    }

    private function kindForComplication(type) as Number or Null {
        if (type == Complications.COMPLICATION_TYPE_STEPS) { return 0; }
        if (type == Complications.COMPLICATION_TYPE_FLOORS_CLIMBED) { return 1; }
        if (type == Complications.COMPLICATION_TYPE_INTENSITY_MINUTES) { return 2; }
        if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) { return 4; }
        if (type == Complications.COMPLICATION_TYPE_STRESS) { return 5; }
        if (type == Complications.COMPLICATION_TYPE_CALORIES) { return 6; }
        return null;
    }

    // Live updates for the bottom field when it shows a system data field.
    // Not needed inside the editor, where a snapshot is enough.
    private function subscribeBottom() as Void {
        if (!_editMode) {
            editorSubscribe([_bottomId], method(:onComplicationChanged));
        }
    }

    function onComplicationChanged(id as Complications.Id) as Void {
        WatchUi.requestUpdate();
    }

    function setEditingSlot(slot) as Void {
        _editingSlot = slot;
        WatchUi.requestUpdate();
    }

    // Screen box [x, y, w, h] of a slot, for tap hit-testing and the editor preview.
    function slotBox(slot) as Array or Null {
        if (_r == 0.0) {
            return null;
        }
        var r = _r;
        if (slot >= 1 && slot <= 4) {
            var g = barGeometry(_cx, _cy, r);
            var x = g[0] + (slot - 1) * (g[1] + g[2]);
            var pad = g[2] / 2.0;
            return [(x - pad).toNumber(), (g[3] - pad).toNumber(),
                (g[1] + 2 * pad).toNumber(), (g[5] - g[3] + r * 0.06 + pad).toNumber()];
        }
        if (slot == 5) {
            var y = _cy + r * HR_Y;
            return [(_cx - r * 0.30).toNumber(), (y - r * 0.08).toNumber(),
                (r * 0.60).toNumber(), (r * 0.16).toNumber()];
        }
        return null;
    }

    function slotAt(x, y) as Number or Null {
        for (var slot = 1; slot <= 5; slot++) {
            var b = slotBox(slot);
            if (b != null && x >= b[0] && x <= b[0] + b[2] && y >= b[1] && y <= b[1] + b[3]) {
                return slot;
            }
        }
        return null;
    }

    function drawSlot(dc, slot) as Void {
        if (!_fontsReady) { buildFonts(dc); }
        if (slot >= 1 && slot <= 4) {
            var g = barGeometry(_cx, _cy, _r);
            drawBar(dc, g[0] + (slot - 1) * (g[1] + g[2]), g[3], g[4], g[1], _bars[slot - 1], g[5], _r);
        } else if (slot == 5) {
            drawBottomField(dc, _cx, _cy, _r);
        }
    }

    // ---------- Fonts ----------

    private function vfont(faces, size, fallback) {
        if (Graphics has :getVectorFont) {
            var f = Graphics.getVectorFont({ :face => faces, :size => size.toNumber() });
            if (f != null) { return f; }
        }
        return systemFont(size, fallback);
    }

    // Without vector fonts: the largest system font no taller than the design size
    // (number fonts only stand in for number fonts, they have no letters).
    private function systemFont(size, fallback) {
        var fonts = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL,
                     Graphics.FONT_MEDIUM, Graphics.FONT_LARGE];
        if (fallback == Graphics.FONT_NUMBER_HOT || fallback == Graphics.FONT_NUMBER_MILD) {
            fonts = [Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM,
                     Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_THAI_HOT];
        }
        var best = fonts[0];
        for (var i = 0; i < fonts.size(); i++) {
            if (Graphics.getFontHeight(fonts[i]) <= size * 1.25) {
                best = fonts[i];
            }
        }
        return best;
    }

    private function buildFonts(dc as Dc) as Void {
        var r = dc.getWidth() / 2.0;
        var bold = ["RobotoCondensedBold", "RobotoRegular"];
        var reg = ["RobotoCondensedRegular", "RobotoRegular"];
        var timeFaces = (_timeWeight == 0) ? bold : reg;
        var stacked = (_layout == 0);

        var k = r * FONT_K;
        _timeFont   = vfont(timeFaces, k * (stacked ? S_TIME_SIZE : C_TIME_SIZE), Graphics.FONT_NUMBER_HOT);
        _aodFont    = vfont(reg, k * AOD_TIME_K * (stacked ? S_TIME_SIZE : C_TIME_SIZE), Graphics.FONT_NUMBER_MILD);
        _hrFont     = vfont(bold, k * HR_SIZE, Graphics.FONT_SMALL);
        _dateFont   = vfont(reg, k * DATE_SIZE, Graphics.FONT_TINY);
        _valFont    = vfont(bold, k * (stacked ? S_VAL_SIZE : C_VAL_SIZE), Graphics.FONT_SMALL);
        _labFont    = vfont(reg, k * 0.056, Graphics.FONT_XTINY);
        _statusFont = vfont(bold, k * STATUS_SIZE, Graphics.FONT_XTINY);
        _fontsReady = true;
    }

    // Bezel minute ticks never change, so their endpoints are computed once.
    private function buildTicks(r) as Void {
        _ticks = [];
        var outer = r * 0.971;
        for (var i = 0; i < 60; i++) {
            var a = i * Math.PI / 30.0;
            var major = (i % 5 == 0);
            var inner = outer - r * (major ? 0.048 : 0.024);
            var sn = Math.sin(a);
            var cs = Math.cos(a);
            _ticks.add([r + outer * sn, r - outer * cs, r + inner * sn, r - inner * cs, major]);
        }
    }

    // ---------- Lifecycle ----------

    function onLayout(dc as Dc) as Void {
        _r = dc.getWidth() / 2.0;
        _cx = dc.getWidth() / 2;
        _cy = dc.getHeight() / 2;
        var settings = System.getDeviceSettings();
        _mip = !((settings has :requiresBurnInProtection) && settings.requiresBurnInProtection);
        buildFonts(dc);
        buildTicks(_r);
    }

    function onExitSleep() as Void {
        _awake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        _awake = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var r = w / 2.0;
        if (!_fontsReady) { buildFonts(dc); }
        if (_ticks == null) { buildTicks(r); }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var clock = System.getClockTime();
        var settings = System.getDeviceSettings();

        var burnIn = (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
        if (!_awake && burnIn && !_editMode) {
            drawAod(dc, cx, cy, r, clock, settings);
            return;
        }

        drawBackground(dc, cx, cy, r);
        drawTicks(dc);
        if (_layout == 0) {
            drawStacked(dc, cx, cy, r, clock, settings);
        } else {
            drawClassic(dc, cx, cy, r, clock, settings);
        }
    }

    private function drawTicks(dc) as Void {
        for (var i = 0; i < _ticks.size(); i++) {
            var t = _ticks[i];
            dc.setPenWidth(t[4] ? 2 : 1);
            dc.setColor(t[4] ? C_TICK_HI : C_TICK, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(t[0], t[1], t[2], t[3]);
        }
        dc.setPenWidth(1);
    }

    // ---------- Layouts ----------

    private function drawStacked(dc, cx, cy, r, clock, settings) as Void {
        drawHeader(dc, cx, cy, r, settings);
        var tr = cx + r * S_TIME_R;
        var just = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tr, cy + r * S_HOUR_Y, _timeFont, hourString(clock, settings), just);
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tr, cy + r * S_MIN_Y, _timeFont, clock.min.format("%02d"), just);
        drawCard(dc, cx, cy, r, S_CARD);
        drawFooter(dc, cx, cy, r);
    }

    private function drawClassic(dc, cx, cy, r, clock, settings) as Void {
        drawHeader(dc, cx, cy, r, settings);
        var y = cy + r * C_TIME_Y;
        var gap = r * C_TIME_GAP;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - gap, y, _timeFont, hourString(clock, settings),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + gap, y, _timeFont, clock.min.format("%02d"),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var dot = r * 0.026;
        dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, y - r * 0.075, dot);
        dc.fillCircle(cx, y + r * 0.080, dot);
        drawCard(dc, cx, cy, r, C_CARD);
        drawFooter(dc, cx, cy, r);
    }

    // Status icons and date, centered at the top of the dial.
    private function drawHeader(dc, cx, cy, r, settings) as Void {
        drawStatus(dc, cx, cy + r * STATUS_Y, r, settings);
        if (_dateFormat != DF_OFF) {
            dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
            drawSpaced(dc, cx, cy + r * DATE_Y, _dateFont, dateString(), r * 0.014);
        }
    }

    // Bottom data field (heart rate by default) and watch battery on the left bezel.
    private function drawFooter(dc, cx, cy, r) as Void {
        if (_editingSlot != 5) {
            drawBottomField(dc, cx, cy, r);
        }
        drawBatteryArc(dc, cx, cy, r);
    }

    // Heart rate with a heart glyph, or - when another field was picked in
    // the watch face editor - that field's label and value.
    private function drawBottomField(dc, cx, cy, r) as Void {
        var y = cy + r * HR_Y;
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        if (_bottomId != null) {
            var ct = complicationText(_bottomId);
            var value = (ct == null) ? "--" : ct[0];
            var label = (ct == null) ? "" : ct[1];
            var gap = r * 0.03;
            var lw = (label.length() > 0) ? dc.getTextWidthInPixels(label, _dateFont) + gap : 0;
            var x = cx - (lw + dc.getTextWidthInPixels(value, _hrFont)) / 2.0;
            if (lw > 0) {
                dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, y, _dateFont, label, left);
            }
            dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + lw, y, _hrFont, value, left);
            return;
        }
        var hr = currentHeartRate();
        var text = (hr == null) ? "--" : hr.format("%d");
        var icon = r * 0.078;
        var pad = r * 0.028;
        var x = cx - (icon + pad + dc.getTextWidthInPixels(text, _hrFont)) / 2.0;
        drawHeart(dc, x + icon / 2.0, y, icon, BAR_COLORS[3]);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + icon + pad, y, _hrFont, text, left);
    }

    // Watch battery as a thin arc on the left bezel (7:30 up to 10:30),
    // filling upward; turns red below 20%.
    private function drawBatteryArc(dc, cx, cy, r) as Void {
        var batt = System.getSystemStats().battery;
        var frac = batt / 100.0;
        if (frac > 1.0) { frac = 1.0; }
        var rr = r * 0.942;
        var pw = (r * 0.024).toNumber();
        if (pw < 3) { pw = 3; }
        dc.setPenWidth(pw);
        dc.setColor(C_ARC_BG, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, rr, Graphics.ARC_CLOCKWISE, 225, 135);
        roundCap(dc, cx, cy, rr, 225, pw);
        roundCap(dc, cx, cy, rr, 135, pw);
        if (frac > 0.01) {
            var end = 225 - 90.0 * frac;
            dc.setColor(batt < 20 ? C_LOW : C_SOFT, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, rr, Graphics.ARC_CLOCKWISE, 225, end);
            roundCap(dc, cx, cy, rr, 225, pw);
            roundCap(dc, cx, cy, rr, end, pw);
        }
        dc.setPenWidth(1);
    }

    private function roundCap(dc, cx, cy, rr, deg, pw) as Void {
        var a = Math.toRadians(deg);
        dc.fillCircle(cx + rr * Math.cos(a), cy - rr * Math.sin(a), pw / 2.0);
    }

    private function currentHeartRate() as Number or Null {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var s = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (s != null && s.heartRate != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return s.heartRate;
            }
        }
        return null;
    }

    private function drawHeart(dc, x, y, s, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s * 0.24, y - s * 0.12, s * 0.27);
        dc.fillCircle(x + s * 0.24, y - s * 0.12, s * 0.27);
        dc.fillPolygon([[x - s * 0.50, y - s * 0.04], [x + s * 0.50, y - s * 0.04], [x, y + s * 0.46]]);
    }

    // ---------- Time and date ----------

    // Zero-padded in 24 h; 1-12 without padding in 12 h (as in ApexFace).
    private function hourString(clock, settings) as String {
        var hour = clock.hour;
        var use24 = (_clockMode == 0) ? settings.is24Hour : (_clockMode == 1);
        if (!use24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return use24 ? hour.format("%02d") : hour.format("%d");
    }

    // Weekday and date by the DateFormat setting: "MON 28 SEP", or day and month padded
    // "MON 28-09-2026" / "MON 09-28-2026". Watch picks the numeric order from the
    // distance units (Connect IQ has no API for the watch's date order): miles = month first.
    private function dateString() as String {
        return FaceKit.localDateText(_dateFormat);
    }

    // Letter-spaced caps (Monkey C text has no tracking option), centered on x.
    private function drawSpaced(dc, x, y, font, text as String, spacing) as Void {
        var chars = text.toCharArray();
        var widths = new [chars.size()];
        var total = spacing * (chars.size() - 1);
        for (var i = 0; i < chars.size(); i++) {
            widths[i] = dc.getTextWidthInPixels(chars[i].toString(), font);
            total += widths[i];
        }
        var px = x - total / 2.0;
        for (var i = 0; i < chars.size(); i++) {
            dc.drawText(px, y, font, chars[i].toString(),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            px += widths[i] + spacing;
        }
    }

    // ---------- Metrics ----------
    // Every metric maps to a 0..1 "how good" fraction so a fuller bar is
    // always better; "lower is better" ones (Move alert, Stress) are inverted.

    private function bodyBatteryLevel() as Number or Null {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getBodyBatteryHistory)) {
            return null;
        }
        var it = SensorHistory.getBodyBatteryHistory({ :period => 1 });
        var sample = it.next();
        if (sample != null && sample.data != null) {
            return sample.data.toNumber();
        }
        return null;
    }

    private function secondsToday() as Number {
        var c = System.getClockTime();
        return c.hour * 3600 + c.min * 60 + c.sec;
    }

    // Garmin's calorie counter includes resting burn (BMR), so a raw total
    // passes any sensible goal by breakfast. Subtract the resting share
    // accrued so far (Mifflin-St Jeor from the user profile) to get the
    // active calories the bar actually tracks.
    private function activeCalories(total as Number) as Number {
        var bmr = 1700.0;
        var p = UserProfile.getProfile();
        if (p != null && p.weight != null && p.height != null && p.birthYear != null) {
            var age = Gregorian.info(Time.now(), Time.FORMAT_SHORT).year - p.birthYear;
            bmr = 10.0 * (p.weight / 1000.0) + 6.25 * p.height - 5.0 * age
                + ((p.gender == UserProfile.GENDER_FEMALE) ? -161.0 : 5.0);
        }
        var active = total - bmr * secondsToday() / 86400.0;
        return active < 0 ? 0 : active.toNumber();
    }

    // Where a cumulative metric "should" be right now: the share of the
    // user's waking day (their own wake/sleep times) that has elapsed.
    private function dayPace() as Float {
        var wake = 7 * 3600;
        var sleep = 22 * 3600;
        var p = UserProfile.getProfile();
        if (p != null && p.wakeTime != null && p.sleepTime != null) {
            wake = p.wakeTime.value();
            sleep = p.sleepTime.value();
        }
        var now = secondsToday();
        if (sleep <= wake) {
            sleep += 86400;
            if (now < wake) { now += 86400; }
        }
        var f = (now - wake).toFloat() / (sleep - wake);
        return f < 0.0 ? 0.0 : (f > 1.0 ? 1.0 : f);
    }

    // Active minutes are a weekly goal, so their pace is the share of the
    // week elapsed, starting from the user's configured first day of week.
    private function weekPace() as Float {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var first = 2;
        var s = System.getDeviceSettings();
        if ((s has :firstDayOfWeek) && s.firstDayOfWeek != null) { first = s.firstDayOfWeek; }
        var days = (info.day_of_week - first + 7) % 7;
        return (days + secondsToday() / 86400.0) / 7.0;
    }

    private function thousands(n as Number, compact as Boolean) as String {
        if (n >= 10000 || (compact && n >= 1000)) {
            return (n / 1000.0).format("%.1f") + "k";
        }
        if (n >= 1000) {
            return (n / 1000).format("%d") + "," + (n % 1000).format("%03d");
        }
        return n.format("%d");
    }

    // Returns [pct (0..1+), value string, pace (0..1, or -1 when pace is meaningless)]
    private function barData(kind, compact as Boolean) as Array {
        var am = ActivityMonitor.getInfo();
        if (kind == 0) {
            var st = (am.steps == null) ? 0 : am.steps;
            var pct = (am.stepGoal != null && am.stepGoal > 0) ? st.toFloat() / am.stepGoal : 0.0;
            return [pct, thousands(st, compact), dayPace()];
        } else if (kind == 1) {
            // No barometer (vívoactive 6, Approach S50): no floors fields at all.
            var fc = ((am has :floorsClimbed) && am.floorsClimbed != null) ? am.floorsClimbed : 0;
            var g = (am has :floorsClimbedGoal) ? am.floorsClimbedGoal : null;
            var pct = (g != null && g > 0) ? fc.toFloat() / g : 0.0;
            return [pct, fc.format("%d"), dayPace()];
        } else if (kind == 2) {
            var total = 0;
            if ((am has :activeMinutesWeek) && am.activeMinutesWeek != null) {
                total = am.activeMinutesWeek.total;
            }
            var g = (am has :activeMinutesWeekGoal) ? am.activeMinutesWeekGoal : null;
            var pct = (g != null && g > 0) ? total.toFloat() / g : 0.0;
            return [pct, total.format("%d") + "m", weekPace()];
        } else if (kind == 3) {
            var level = ((am has :moveBarLevel) && am.moveBarLevel != null) ? am.moveBarLevel : 0;
            return [1.0 - level / 5.0, level == 0 ? "OK" : level.format("%d"), -1.0];
        } else if (kind == 4) {
            var bb = bodyBatteryLevel();
            return [(bb == null) ? 0.0 : bb / 100.0, bb == null ? "--" : bb.format("%d"), -1.0];
        } else if (kind == 5) {
            var s = (am has :stressScore) ? am.stressScore : null;
            return [(s == null) ? 0.0 : (100 - s) / 100.0, s == null ? "--" : s.format("%d"), -1.0];
        }
        var kcal = activeCalories(am.calories == null ? 0 : am.calories);
        return [kcal.toFloat() / _kcalGoal,thousands(kcal, compact), dayPace()];
    }

    // ---------- Bars ----------

    // The data card: a dark rounded panel with a fine diagonal hatch (the
    // texture Garmin's own FR970/265 faces use), holding the four bars with
    // their values along the bottom edge.
    private function drawCard(dc, cx, cy, r, card) as Void {
        var x0 = cx + r * card[0];
        var y0 = cy + r * card[1];
        var w = r * card[2];
        var h = r * card[3];
        var rad = r * CARD_RADIUS;

        dc.setColor(C_CARD_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, y0, w, h, rad);
        drawHatch(dc, x0, y0, w, h, rad, r);
        dc.setColor(C_CARD_EDGE, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x0, y0, w, h, rad);

        var g = barGeometry(cx, cy, r);
        for (var i = 0; i < _bars.size(); i++) {
            if (_editingSlot != i + 1) {
                drawBar(dc, g[0] + i * (g[1] + g[2]), g[3], g[4], g[1], _bars[i], g[5], r);
            }
        }
    }

    // [first bar x, bar width, gap, track top, track bottom, value y] for the current layout.
    private function barGeometry(cx, cy, r) as Array {
        var stacked = (_layout == 0);
        var card = stacked ? S_CARD : C_CARD;
        var x0 = cx + r * card[0];
        var y0 = cy + r * card[1];
        var w = r * card[2];
        var h = r * card[3];
        var n = _bars.size();
        var barW = r * (stacked ? S_BAR_W : C_BAR_W);
        var gap = r * (stacked ? S_BAR_GAP : C_BAR_GAP);
        return [x0 + (w - (n * barW + (n - 1) * gap)) / 2.0, barW, gap,
            y0 + r * CARD_PAD_T, y0 + h - r * CARD_PAD_B, y0 + h - r * CARD_VAL_B];
    }

    // Hatch lines are clipped to two overlapping bands (the card minus its
    // corner squares), since Monkey C can only clip to rectangles.
    private function drawHatch(dc, x0, y0, w, h, rad, r) as Void {
        var step = r * 0.029;
        var slant = h * 0.35;
        dc.setColor(C_HATCH, Graphics.COLOR_TRANSPARENT);
        var bands = [[x0, y0 + rad, w, h - 2 * rad], [x0 + rad, y0, w - 2 * rad, h]];
        for (var b = 0; b < 2; b++) {
            var c = bands[b];
            dc.setClip(c[0], c[1], c[2], c[3]);
            for (var t = x0; t < x0 + w + slant; t += step) {
                dc.drawLine(t, y0 + h, t - slant, y0);
            }
        }
        dc.clearClip();
    }

    private function drawBar(dc, x, top, bot, barW, kind, valY, r) as Void {
        var data = barData(kind, _layout == 0);
        var pct = data[0];
        var color = BAR_COLORS[kind];
        var rad = barW / 2.0;
        var h = bot - top;

        // MIP screens have 64 colours: a dim tint of each bar rounds to a muddy
        // red or navy, so the tracks are one dark grey there.
        dc.setColor(_mip ? 0x555555 : scaleColor(color, TRACK_TINT), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, top, barW, h, rad);
        if (pct > 0.005) {
            var fillH = h * (pct > 1.0 ? 1.0 : pct);
            if (fillH < barW) { fillH = barW; }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, bot - fillH, barW, fillH, rad);
            if (pct >= 1.0) {
                drawCheck(dc, x + rad, top + rad, barW);
            }
        }

        // Pace: a white line across the bar where the metric should be by now.
        var pace = data[2];
        if (_showPace && pace > 0.0 && pct < 1.0) {
            var ext = r * 0.014;
            var th = r * 0.012;
            dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x - ext, bot - h * pace - th / 2.0, barW + 2 * ext, th, th / 2.0);
        }

        var pitch = r * (_layout == 0 ? S_BAR_W + S_BAR_GAP : C_BAR_W + C_BAR_GAP) - 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + rad, valY, _valFont, fitValue(dc, data[1] as String, pitch),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // On small screens without vector fonts "8.4k" is wider than a bar's pitch:
    // drop the decimal there ("8k").
    private function fitValue(dc, s as String, maxW) as String {
        if (dc.getTextWidthInPixels(s, _valFont) <= maxW) { return s; }
        var dot = s.find(".");
        if (dot == null || dot + 2 > s.length()) { return s; }
        return s.substring(0, dot) + s.substring(dot + 2, s.length());
    }

    // Goal met: a black check mark punched into the bar's top cap.
    private function drawCheck(dc, x, y, s) as Void {
        var pw = (s * 0.13).toNumber();
        if (pw < 2) { pw = 2; }
        var p1 = [x - s * 0.20, y + s * 0.01];
        var p2 = [x - s * 0.06, y + s * 0.15];
        var p3 = [x + s * 0.21, y - s * 0.13];
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw);
        dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        dc.drawLine(p2[0], p2[1], p3[0], p3[1]);
        dc.fillCircle(p1[0], p1[1], pw / 2.0);
        dc.fillCircle(p2[0], p2[1], pw / 2.0);
        dc.fillCircle(p3[0], p3[1], pw / 2.0);
        dc.setPenWidth(1);
    }

    private function scaleColor(c as Number, k as Float) as Number {
        var rr = (((c >> 16) & 0xFF) * k).toNumber();
        var gg = (((c >> 8) & 0xFF) * k).toNumber();
        var bb = ((c & 0xFF) * k).toNumber();
        return (rr << 16) | (gg << 8) | bb;
    }

    // ---------- Status row ----------
    // Only shows what's relevant: unread notifications, set alarms, and DND
    // when it's on. Zero-count items are hidden rather than shown as "0".

    private function drawStatus(dc, cx, y, r, settings) as Void {
        var items = [];
        if (_showNotif && settings.notificationCount != null && settings.notificationCount > 0) {
            items.add([0, settings.notificationCount]);
        }
        if (_showAlarms && (settings has :alarmCount) && settings.alarmCount != null && settings.alarmCount > 0) {
            items.add([1, settings.alarmCount]);
        }
        if (_showDnd && (settings has :doNotDisturb) && settings.doNotDisturb) {
            items.add([2, 0]);
        }
        if (items.size() == 0) { return; }

        var icon = r * 0.058;
        var pad = r * 0.022;
        var gap = r * 0.075;
        var widths = new [items.size()];
        var total = gap * (items.size() - 1);
        for (var i = 0; i < items.size(); i++) {
            var w = icon;
            if (items[i][0] != 2) {
                w += pad + dc.getTextWidthInPixels(items[i][1].format("%d"), _statusFont);
            }
            widths[i] = w;
            total += w;
        }

        var x = cx - total / 2.0;
        for (var i = 0; i < items.size(); i++) {
            var kind = items[i][0];
            if (kind == 0) {
                dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + icon / 2.0, y, icon * 0.32);
            } else if (kind == 1) {
                drawAlarm(dc, x, y, icon, C_ALARM);
            } else {
                drawMoon(dc, x, y, icon, C_DND);
            }
            if (kind != 2) {
                dc.setColor(C_SOFT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x + icon + pad, y, _statusFont, items[i][1].format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            x += widths[i] + gap;
        }
        dc.setPenWidth(1);
    }

    private function drawMoon(dc, x, y, s, color) as Void {
        var mx = x + s / 2.0;
        var R = s / 2.0;
        var ix = mx + R * 0.55;
        var pts = [];
        var steps = 12;
        for (var i = 0; i <= steps; i++) {
            var t = Math.toRadians(74 + 212.0 * i / steps);
            pts.add([mx + R * Math.cos(t), y - R * Math.sin(t)]);
        }
        for (var i = steps; i >= 0; i--) {
            var t = Math.toRadians(106 + 148.0 * i / steps);
            pts.add([ix + R * Math.cos(t), y - R * Math.sin(t)]);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
    }

    private function drawAlarm(dc, x, y, s, color) as Void {
        var pen = (s * 0.14).toNumber();
        if (pen < 2) { pen = 2; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawCircle(x + s / 2.0, y, s * 0.42);
    }

    // ---------- Always-on (low power) ----------
    // Like ApexFace: nothing accent-colored, a thinner and slightly smaller time
    // in grays at the awake position (so nothing jumps when the wrist drops), the
    // 12 hour ticks, the date in both layouts, and one dot per bar where the card
    // was (filled in the metric's color once its goal is met). Everything moves
    // together each minute against burn-in; the ticks are inset by the largest shift.

    private function drawAod(dc, cx, cy, r, clock, settings) as Void {
        // FaceCore burn-in drift (design px of the 454 screen, scaled to this one)
        var s = FaceKit.aodShift(clock.min);
        var dx = s[0] * r / FaceKit.C;
        var dy = s[1] * r / FaceKit.C;
        var card;

        drawAodTicks(dc, cx + dx, cy + dy, r);
        if (_aodDate && _dateFormat != DF_OFF) {
            dc.setColor(C_AOD_DIM, Graphics.COLOR_TRANSPARENT);
            drawSpaced(dc, cx + dx, cy + r * DATE_Y + dy, _dateFont, dateString(), r * 0.014);
        }

        if (_layout == 0) {
            var tr = cx + r * S_TIME_R + dx;
            var just = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
            dc.setColor(C_AOD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tr, cy + r * S_HOUR_Y + dy, _aodFont, hourString(clock, settings), just);
            dc.setColor(C_AOD_MIN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tr, cy + r * S_MIN_Y + dy, _aodFont, clock.min.format("%02d"), just);
            card = S_CARD;
        } else {
            var y = cy + r * C_TIME_Y + dy;
            var gap = r * C_TIME_GAP;
            dc.setColor(C_AOD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + dx - gap, y, _aodFont, hourString(clock, settings),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(C_AOD_MIN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + dx + gap, y, _aodFont, clock.min.format("%02d"),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(C_AOD_DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + dx, y - r * 0.075, r * 0.022);
            dc.fillCircle(cx + dx, y + r * 0.080, r * 0.022);
            card = C_CARD;
        }
        var step = r * 0.077;
        drawAodDots(dc, cx + r * (card[0] + card[2] / 2.0) - step * 1.5 + dx,
            cy + r * (card[1] + card[3] / 2.0) + dy, r);
    }

    // The 12 hour ticks of the bezel, dim, pulled in by the burn-in shift.
    private function drawAodTicks(dc, cx, cy, r) as Void {
        var outer = r * (0.971 - AOD_SHIFT * 1.5);
        var inner = outer - r * 0.048;
        var pw = (r * 0.012).toNumber();
        dc.setPenWidth(pw < 2 ? 2 : pw);
        dc.setColor(C_AOD_TICK, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var a = i * Math.PI / 6.0;
            var sn = Math.sin(a);
            var cs = Math.cos(a);
            dc.drawLine(cx + outer * sn, cy - outer * cs, cx + inner * sn, cy - inner * cs);
        }
        dc.setPenWidth(1);
    }

    private function drawAodDots(dc, x, y, r) as Void {
        var step = r * 0.077;
        var rad = r * 0.024;
        for (var i = 0; i < _bars.size(); i++) {
            var kind = _bars[i];
            var pct = barData(kind, true)[0];
            if (pct >= 1.0) {
                dc.setColor(BAR_COLORS[kind], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + i * step, y, rad);
            } else {
                dc.setColor(scaleColor(BAR_COLORS[kind], 0.7), Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawCircle(x + i * step, y, rad * 0.9);
            }
        }
        dc.setPenWidth(1);
    }

    // ---------- Abstract backgrounds ----------

    private function shade(f) as Number {
        var base = (_bgColorMode == 0) ? _accent : C_BG_GRAY;
        var k = f * BG_LEVELS[_bgIntensity];
        var rr = (((base >> 16) & 0xFF) * k).toNumber();
        var gg = (((base >> 8) & 0xFF) * k).toNumber();
        var bb = ((base & 0xFF) * k).toNumber();
        return (rr << 16) | (gg << 8) | bb;
    }

    private function bgPen(r) as Number {
        var p = (r * 0.01).toNumber();
        return (p < 1) ? 1 : p;
    }

    private function drawBackground(dc, cx, cy, r) as Void {
        if (_bgStyle == 1) { bgOrbits(dc, cx, cy, r); }
        else if (_bgStyle == 2) { bgWaves(dc, cx, cy, r); }
        else if (_bgStyle == 3) { bgDots(dc, cx, cy, r); }
        else if (_bgStyle == 4) { bgBlobs(dc, cx, cy, r); }
        else if (_bgStyle == 5) { bgTopo(dc, cx, cy, r); }
        else if (_bgStyle == 6) { bgRays(dc, cx, cy, r); }
        else if (_bgStyle == 7) { bgImage(dc, :BgAurora); }
        else if (_bgStyle == 8) { bgImage(dc, :BgSpace); }
        dc.setPenWidth(1);
    }

    // Static baked-image backgrounds. Loaded once and cached (loadResource
    // is relatively expensive); the correct device-resolution PNG is picked
    // automatically at build time via the resources-fr265/-fr265s/-fr970
    // per-device resource folders, so this code doesn't need to know sizes.
    private function bgImage(dc, symbol) as Void {
        if (_bgImageSymbol != symbol) {
            var res = null;
            if (symbol == :BgAurora) {
                res = WatchUi.loadResource(Rez.Drawables.BgAurora);
            } else {
                res = WatchUi.loadResource(Rez.Drawables.BgSpace);
            }
            _bgImage = res;
            _bgImageSymbol = symbol;
        }
        if (_bgImage != null) {
            dc.drawBitmap(0, 0, _bgImage);
        }
    }

    private function bgOrbits(dc, cx, cy, r) as Void {
        var ox = cx + r * 0.45;
        var oy = cy - r * 0.40;
        dc.setPenWidth(bgPen(r));
        for (var i = 1; i <= 9; i++) {
            dc.setColor(shade(1.0 - i * 0.07), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(ox, oy, r * 0.16 * i);
        }
        var px = cx - r * 0.55;
        var py = cy + r * 0.60;
        dc.setColor(shade(0.6), Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i <= 4; i++) {
            dc.drawCircle(px, py, r * 0.10 * i);
        }
        dc.setColor(shade(1.0), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ox, oy, r * 0.05);
    }

    private function bgWaves(dc, cx, cy, r) as Void {
        var seg = 36;
        var step = (2.0 * r) / seg;
        dc.setPenWidth(bgPen(r));
        for (var j = 0; j < 9; j++) {
            var baseY = cy - r * 0.95 + j * r * 0.24;
            var amp = r * (0.04 + 0.012 * j);
            var phase = j * 0.7;
            dc.setColor(shade(0.5 + 0.25 * (j % 3)), Graphics.COLOR_TRANSPARENT);
            var px = cx - r;
            var py = baseY + amp * Math.sin(phase);
            for (var i = 1; i <= seg; i++) {
                var x = cx - r + i * step;
                var y = baseY + amp * Math.sin(phase + i * 0.35);
                dc.drawLine(px, py, x, y);
                px = x;
                py = y;
            }
        }
    }

    private function bgDots(dc, cx, cy, r) as Void {
        var sp = r * 0.1;
        var fx = cx + r * 0.6;
        var fy = cy - r * 0.6;
        var n = (2.0 * r / sp).toNumber() + 1;
        dc.setColor(shade(1.0), Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < n; j++) {
            for (var i = 0; i < n; i++) {
                var x = cx - r + i * sp + (j % 2) * sp / 2.0;
                var y = cy - r + j * sp;
                var dx = x - cx;
                var dy = y - cy;
                if (dx * dx + dy * dy > r * r) { continue; }
                var d = Math.sqrt((x - fx) * (x - fx) + (y - fy) * (y - fy)) / (2.0 * r);
                var size = sp * 0.32 * (1.0 - d);
                if (size < 0.8) { continue; }
                dc.fillCircle(x, y, size);
            }
        }
    }

    private function bgBlobs(dc, cx, cy, r) as Void {
        dc.setColor(shade(0.55), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + r * 0.75, cy - r * 0.55, r * 0.62);
        dc.setColor(shade(0.90), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + r * 0.95, cy - r * 0.20, r * 0.38);
        dc.setColor(shade(0.40), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 0.85, cy + r * 0.70, r * 0.70);
        dc.setColor(shade(0.70), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 0.55, cy + r * 1.05, r * 0.40);
    }

    private function bgTopo(dc, cx, cy, r) as Void {
        var ox = cx - r * 0.25;
        var oy = cy + r * 0.15;
        var seg = 48;
        dc.setPenWidth(bgPen(r));
        for (var k = 1; k <= 6; k++) {
            var base = r * 0.17 * k;
            dc.setColor(shade((k % 2 == 0) ? 1.0 : 0.6), Graphics.COLOR_TRANSPARENT);
            var px = 0.0;
            var py = 0.0;
            for (var i = 0; i <= seg; i++) {
                var t = 2.0 * Math.PI * i / seg;
                var rad = base * (1.0 + 0.08 * Math.sin(3 * t + k * 0.9) + 0.05 * Math.sin(5 * t - k * 0.5));
                var x = ox + rad * Math.cos(t);
                var y = oy + rad * Math.sin(t);
                if (i > 0) { dc.drawLine(px, py, x, y); }
                px = x;
                py = y;
            }
        }
    }

    private function bgRays(dc, cx, cy, r) as Void {
        var ox = cx - r * 1.05;
        var oy = cy + r * 1.05;
        dc.setPenWidth(bgPen(r));
        for (var i = 0; i < 14; i++) {
            var a = Math.toRadians(8 + i * 6.0);
            dc.setColor(shade((i % 3 == 0) ? 1.0 : 0.5), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(ox, oy, ox + 3.0 * r * Math.cos(a), oy - 3.0 * r * Math.sin(a));
        }
    }
}
