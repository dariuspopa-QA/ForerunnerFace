import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.Weather;
import Toybox.WatchUi;

// ---------- Colors ----------
const ACCENTS = [0xB6F24A, 0x5AC8FA, 0xFF9F0A, 0xFF6B9D, 0xF2F2F7];
const C_WHITE   = 0xFFFFFF;
const C_GRAY    = 0x8E8E93;
const C_OFF     = 0x3A3A3C;
const C_DIVIDER = 0x2C2C2E;
const C_ALARM   = 0xFFB340;
const C_DND     = 0xA78BFA;
const C_AOD     = 0x9A9A9F;
const C_AOD_DIM = 0x5E5E62;
const C_AOD_TICK = 0x4A4A46;
const AOD_SHIFT = 0.044;  // largest FaceKit.aodShift offset (10 of 227 design px), fraction of radius
const C_BG_GRAY = 0xB0B0B8;

// Heart-rate zone colors, zone 1 (coolest) to zone 5 (hottest).
const HR_ZONE_COLORS = [0x8E8E93, 0x5AC8FA, 0xB6F24A, 0xFFB340, 0xFF453A];

const BG_LEVELS = [0.14, 0.24, 0.36];

// ---------- Layout (fractions of screen radius, from center) ----------
const Y_STATUS  = -0.72;
const Y_DATE    = -0.54;
const Y_TIME    = -0.32;
const Y_V1      = -0.05;
const Y_L1      =  0.06;
const Y_V2      =  0.21;
const Y_L2      =  0.32;
const Y_V3      =  0.47;
const Y_L3      =  0.58;
const Y_SUN     =  0.72;
const X_FIELD   =  0.32;
const TIME_SIZE =  0.27;
const AOD_SIZE  =  0.36;
const ICON_SIZE =  0.078;
const ICON_GAP  =  0.075;

// DateFormat setting (as in ApexFace): follow the watch (order from its distance units),
// "MON 28 SEP", "MON 28-09-2026", "MON 09-28-2026", or no date
const DF_WATCH = 0;
const DF_NAMED = 1;
const DF_DMY   = 2;
const DF_MDY   = 3;
const DF_OFF   = 4;

class TrainingPulseView extends WatchUi.WatchFace {

    // Settings
    private var _accent = 0xB6F24A;
    private var _bgStyle = 0;
    private var _bgIntensity = 0;
    private var _bgColorMode = 0;
    private var _clockMode = 0;
    private var _dateFormat = 0;
    private var _fields = [0, 5, 9, 2, 10, 3];
    private var _showNotif = true;
    private var _showAlarms = true;
    private var _showDnd = true;
    private var _showSun = true;
    private var _aodDate = true;

    // State
    private var _awake = true;
    private var _fontsReady = false;
    private var _timeFont = Graphics.FONT_NUMBER_MEDIUM;
    private var _aodFont = Graphics.FONT_NUMBER_MILD;
    private var _labelFont = Graphics.FONT_XTINY;
    private var _dateFont = Graphics.FONT_XTINY;
    private var _valueFont = Graphics.FONT_TINY;

    // Native watch face editor (see EditorConfig.mc).
    // Slots 1-6 = grid fields, left to right, top to bottom.
    private var _editMode = false;
    private var _editingSlot = null;
    private var _fieldIds = [null, null, null, null, null, null];  // system data fields
    private var _phone = {};  // phone app values of the settings the editor also sets
    private var _r = 0.0;
    private var _cx = 0;
    private var _cy = 0;

    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        _editMode = editMode;
        loadSettings();
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

    function loadSettings() as Void {
        var idx = prop("AccentColor", 0);
        if (idx < 0 || idx >= ACCENTS.size()) { idx = 0; }
        _accent      = ACCENTS[idx];
        _bgStyle     = prop("BgStyle", 0);
        if (_bgStyle < 0 || _bgStyle > 6) { _bgStyle = 0; }
        _bgIntensity = prop("BgIntensity", 0);
        if (_bgIntensity < 0 || _bgIntensity >= BG_LEVELS.size()) { _bgIntensity = 0; }
        _bgColorMode = prop("BgColor", 0);
        _clockMode   = prop("ClockMode", 0);
        _dateFormat  = prop("DateFormat", 0);
        _fields = [
            prop("Field1", 0), prop("Field2", 5), prop("Field3", 9),
            prop("Field4", 2), prop("Field5", 10), prop("Field6", 3)
        ];
        _showNotif   = prop("ShowNotifications", true);
        _showAlarms  = prop("ShowAlarms", true);
        _showDnd     = prop("ShowDnd", true);
        _showSun     = prop("ShowSunTimes", true);
        _aodDate     = prop("AodShowDate", true);
        _fieldIds    = [null, null, null, null, null, null];
        _fontsReady  = false;
        _phone = { "bg" => _bgStyle, "acc" => idx };
        for (var i = 0; i < 6; i++) {
            _phone["f" + (i + 1)] = _fields[i];
        }
        applyEditor(editorSettings(null), null);
    }

    // ---------- Native watch face editor ----------
    // Style = background pattern, Data = the six grid fields, Accent = accent color.
    //
    // The face itself (not the editor preview) takes each of these from whichever
    // side changed it last, the on-device editor or the phone app, so a change in
    // Garmin Connect still works after the editor has been used.

    function applyEditor(s, editedType) as Void {
        if (s == null) {
            return;
        }
        var mem = _editMode ? null : storedSources();
        if (s.styleId != null && s.styleId >= 1 && s.styleId <= 7
                && editorWins(mem, "bg", s.styleId)) {
            _bgStyle = s.styleId - 1;
        }
        if (s.accentColor != null && s.accentColor.color != null
                && editorWins(mem, "acc", s.accentColor.color)) {
            _accent = s.accentColor.color;
        }
        var refs = s.complicationSettings;
        if (refs != null) {
            for (var i = 0; i < refs.size(); i++) {
                var slot = refs[i].uniqueIdentifier;
                if (slot != null && slot >= 1 && slot <= 6) {
                    var id = refs[i].complicationId;
                    var type = complicationType(id);
                    if (type == null || !editorWins(mem, "f" + slot, type)) {
                        continue;
                    }
                    var kind = fieldKindFor(type);
                    if (kind != null) {
                        _fields[slot - 1] = kind;
                    }
                    _fieldIds[slot - 1] = (kind == null) ? id : null;
                }
            }
        }
        if (mem != null) {
            try {
                Application.Storage.setValue("sources", mem);
            } catch (e) {
                // Not saved: the editor wins again next time, as before
            }
        }
        if (editedType != WatchUi.WATCH_FACE_CONFIG_TYPE_COMPLICATION) {
            _editingSlot = null;
        }
        if (!_editMode) {
            editorSubscribe(_fieldIds, method(:onComplicationChanged));
        }
        WatchUi.requestUpdate();
    }

    // What each setting last was on both sides: key => [editor, phone, editor wins].
    private function storedSources() as Dictionary {
        var mem = null;
        try {
            mem = Application.Storage.getValue("sources");
        } catch (e) {
            mem = null;
        }
        return (mem instanceof Dictionary) ? mem : {};
    }

    // Whether the editor's value for this setting beats the phone's: the side
    // that changed since last time wins, otherwise the last winner stays.
    // Seen for the first time, the editor wins (what the face showed before).
    private function editorWins(mem, key as String, editorVal) as Boolean {
        if (mem == null) {
            return true;  // editor preview
        }
        var phoneVal = _phone[key];
        var prev = mem[key];
        var wins;
        if (!(prev instanceof Array) || prev.size() != 3) {
            wins = true;
        } else if (editorVal != prev[0]) {
            wins = true;
        } else if (phoneVal != prev[1]) {
            wins = false;
        } else {
            wins = prev[2];
        }
        mem[key] = [editorVal, phoneVal, wins];
        return wins;
    }

    // Built-in field for a data type the face already draws itself.
    private function fieldKindFor(type) as Number or Null {
        if (type == Complications.COMPLICATION_TYPE_HEART_RATE) { return 0; }
        if (type == Complications.COMPLICATION_TYPE_STRESS) { return 1; }
        if (type == Complications.COMPLICATION_TYPE_RECOVERY_TIME) { return 2; }
        if (type == Complications.COMPLICATION_TYPE_CALORIES) { return 3; }
        if (type == Complications.COMPLICATION_TYPE_BATTERY) { return 4; }
        if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) { return 5; }
        if (type == Complications.COMPLICATION_TYPE_STEPS) { return 6; }
        if (type == Complications.COMPLICATION_TYPE_FLOORS_CLIMBED) { return 7; }
        if (type == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE) { return 10; }
        return null;
    }

    function onComplicationChanged(id as Complications.Id) as Void {
        WatchUi.requestUpdate();
    }

    function setEditingSlot(slot) as Void {
        _editingSlot = slot;
        WatchUi.requestUpdate();
    }

    function slotBox(slot) as Array or Null {
        if (_r == 0.0 || slot == null || slot < 1 || slot > 6) {
            return null;
        }
        var r = _r;
        var row = (slot - 1) / 2;
        var x = _cx + (((slot - 1) % 2 == 0) ? -1 : 1) * r * X_FIELD;
        var vy = [Y_V1, Y_V2, Y_V3][row];
        return [(x - r * 0.28).toNumber(), (_cy + r * (vy - 0.08)).toNumber(),
            (r * 0.56).toNumber(), (r * 0.25).toNumber()];
    }

    function slotAt(x, y) as Number or Null {
        for (var slot = 1; slot <= 6; slot++) {
            var b = slotBox(slot);
            if (b != null && x >= b[0] && x <= b[0] + b[2] && y >= b[1] && y <= b[1] + b[3]) {
                return slot;
            }
        }
        return null;
    }

    function drawSlot(dc, slot) as Void {
        if (!_fontsReady) { buildFonts(dc); }
        drawGridField(dc, _cx, _cy, _r, slot);
    }

    // ---------- Fonts ----------

    private function buildFonts(dc as Dc) as Void {
        var w = dc.getWidth();
        var r = w / 2.0;
        _timeFont = Graphics.FONT_NUMBER_MEDIUM;
        _aodFont = Graphics.FONT_NUMBER_MILD;
        _labelFont = Graphics.FONT_XTINY;
        _dateFont = Graphics.FONT_XTINY;
        _valueFont = Graphics.FONT_TINY;
        if (Graphics has :getVectorFont) {
            var faces = ["RobotoCondensedRegular", "RobotoRegular"];
            var f = Graphics.getVectorFont({ :face => faces, :size => (r * TIME_SIZE).toNumber() });
            if (f != null) { _timeFont = f; }
            var a = Graphics.getVectorFont({ :face => ["RobotoCondensedLight", "RobotoCondensedRegular", "RobotoRegular"], :size => (r * AOD_SIZE).toNumber() });
            if (a != null) { _aodFont = a; }

            var l = Graphics.getVectorFont({ :face => faces, :size => (dc.getFontHeight(Graphics.FONT_XTINY) * 0.8).toNumber() });
            if (l != null) { _labelFont = l; }
            var d = Graphics.getVectorFont({ :face => faces, :size => (dc.getFontHeight(Graphics.FONT_XTINY) * 0.8).toNumber() });
            if (d != null) { _dateFont = d; }
            var v = Graphics.getVectorFont({ :face => faces, :size => (dc.getFontHeight(Graphics.FONT_TINY) * 0.8).toNumber() });
            if (v != null) { _valueFont = v; }
        }
        _fontsReady = true;
    }

    // ---------- Lifecycle ----------

    function onLayout(dc as Dc) as Void {
        _r = dc.getWidth() / 2.0;
        _cx = dc.getWidth() / 2;
        _cy = dc.getHeight() / 2;
        buildFonts(dc);
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
        var h = dc.getHeight();
        if (!_fontsReady) { buildFonts(dc); }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = w / 2;
        var cy = h / 2;
        var r = w / 2.0;
        var clock = System.getClockTime();
        var settings = System.getDeviceSettings();

        var burnIn = (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
        if (!_awake && burnIn && !_editMode) {
            drawAod(dc, cx, cy, r, clock, settings);
            return;
        }

        drawBackground(dc, cx, cy, r);
        drawStatus(dc, cx, cy, r, settings);
        if (_dateFormat != DF_OFF) {
            dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + r * Y_DATE, _dateFont, dateString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        drawTime(dc, cx, cy + r * Y_TIME, clock, settings, _timeFont, C_WHITE);
        drawGrid(dc, cx, cy, r);
        if (_showSun) {
            drawSunTimes(dc, cx, cy, r);
        }
    }

    // ---------- Time and date ----------

    // [hours, minutes] by the Clock format setting: zero-padded 24 h, or 1-12
    // unpadded in 12 h (no AM/PM marker, as in ApexFace)
    private function timeParts(hour, min, settings) as Array {
        var use24 = (_clockMode == 0) ? settings.is24Hour : (_clockMode == 1);
        if (use24) {
            return [hour.format("%02d"), min.format("%02d")];
        }
        hour = hour % 12;
        if (hour == 0) { hour = 12; }
        return [hour.format("%d"), min.format("%02d")];
    }

    private function timeString(clock, settings) as String {
        var t = timeParts(clock.hour, clock.min, settings);
        return t[0] + ":" + t[1];
    }

    private function drawTime(dc, cx, y, clock, settings, font, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, timeString(clock, settings),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Weekday and date by the DateFormat setting: "MON 28 SEP", or day and month padded
    // "MON 28-09-2026" / "MON 09-28-2026". Watch picks the numeric order from the
    // distance units (Connect IQ has no API for the watch's date order): miles = month first.
    private function dateString() as String {
        return FaceKit.localDateText(_dateFormat);
    }

    // ---------- Data grid ----------

    private function heartRate() {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return sample.heartRate;
            }
        }
        return null;
    }

    private function hrZoneColor(hr) as Number {
        if (hr == null) { return C_WHITE; }
        var zones = null;
        try {
            zones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
        } catch (e) {
            zones = null;
        }
        if (zones == null || zones.size() < 6) { return C_WHITE; }
        if (hr < zones[1]) { return HR_ZONE_COLORS[0]; }
        if (hr < zones[2]) { return HR_ZONE_COLORS[1]; }
        if (hr < zones[3]) { return HR_ZONE_COLORS[2]; }
        if (hr < zones[4]) { return HR_ZONE_COLORS[3]; }
        return HR_ZONE_COLORS[4];
    }

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

    private function currentStress() as Number or Null {
        var am = ActivityMonitor.getInfo();
        if (am has :stressScore && am.stressScore != null) {
            return am.stressScore;
        }
        return null;
    }

    private function isMetric() as Boolean {
        var settings = System.getDeviceSettings();
        return !(settings has :distanceUnits) || settings.distanceUnits != System.UNIT_STATUTE;
    }

    private function distanceString(cm) as String {
        if (cm == null) { return "--"; }
        if (isMetric()) {
            return (cm / 100000.0).format("%.1f");
        }
        return (cm / 160934.0).format("%.1f"); // cm -> miles
    }

    // Today plus the 6 days before it (the history holds previous days only, newest first)
    private function weekDistanceCm() as Number {
        var today = ActivityMonitor.getInfo().distance;
        var total = (today == null) ? 0 : today;
        var hist = ActivityMonitor.getHistory();
        var n = (hist.size() < 6) ? hist.size() : 6;
        for (var i = 0; i < n; i++) {
            var d = hist[i].distance;
            if (d != null) { total += d; }
        }
        return total;
    }

    private function weatherTempString() as String {
        if (!(Toybox has :Weather) || !(Weather has :getCurrentConditions)) { return "--"; }
        var cond = Weather.getCurrentConditions();
        if (cond == null || cond.temperature == null) { return "--"; }
        var c = cond.temperature;
        var settings = System.getDeviceSettings();
        var metric = !(settings has :temperatureUnits) || settings.temperatureUnits != System.UNIT_STATUTE;
        if (metric) {
            return c.format("%d") + "C";
        }
        return (c * 9.0 / 5.0 + 32).format("%d") + "F";
    }

    // Returns [value, label, color or null]
    private function fieldData(kind) as Array {
        if (kind == 0) {
            var hr = heartRate();
            return [hr == null ? "--" : hr.format("%d"), "BPM", hrZoneColor(hr)];
        } else if (kind == 1) {
            var st = currentStress();
            return [st == null ? "--" : st.format("%d"), "STRESS", null];
        } else if (kind == 2) {
            var am = ActivityMonitor.getInfo();
            var rec = (am has :timeToRecovery) ? am.timeToRecovery : null;
            return [rec == null ? "--" : rec.format("%d") + "h", "RECOVERY", null];
        } else if (kind == 3) {
            var cal = ActivityMonitor.getInfo().calories;
            return [cal == null ? "--" : cal.format("%d"), "KCAL", null];
        } else if (kind == 4) {
            return [System.getSystemStats().battery.toNumber().format("%d") + "%", "BATTERY", null];
        } else if (kind == 5) {
            var bb = bodyBatteryLevel();
            return [bb == null ? "--" : bb.format("%d"), "BODY", null];
        } else if (kind == 6) {
            var steps = ActivityMonitor.getInfo().steps;
            return [shortNumber(steps == null ? 0 : steps), "STEPS", null];
        } else if (kind == 7) {
            var fl = ActivityMonitor.getInfo().floorsClimbed;
            return [fl == null ? "--" : fl.format("%d"), "FLOORS", null];
        } else if (kind == 8) {
            var dist = ActivityMonitor.getInfo().distance;
            return [distanceString(dist), isMetric() ? "KM TODAY" : "MI TODAY", null];
        } else if (kind == 9) {
            return [distanceString(weekDistanceCm()), isMetric() ? "KM / 7D" : "MI / 7D", null];
        }
        return [weatherTempString(), "TEMP", null];
    }

    private function drawGrid(dc, cx, cy, r) as Void {
        dc.setColor(C_DIVIDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx, cy + r * (Y_V1 - 0.06), cx, cy + r * (Y_L3 + 0.04));

        for (var slot = 1; slot <= 6; slot++) {
            if (_editingSlot != slot) {
                drawGridField(dc, cx, cy, r, slot);
            }
        }
    }

    // One grid cell: a built-in field (heart rate keeps its zone color), or
    // the system data field picked in the watch face editor.
    private function drawGridField(dc, cx, cy, r, slot) as Void {
        var id = _fieldIds[slot - 1];
        var data;
        if (id != null) {
            var ct = complicationText(id);
            data = (ct == null) ? ["--", "", null] : [ct[0], ct[1], null];
        } else {
            data = fieldData(_fields[slot - 1]);
        }
        var row = (slot - 1) / 2;
        var x = cx + (((slot - 1) % 2 == 0) ? -1 : 1) * r * X_FIELD;
        var just = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor((data[2] == null) ? C_WHITE : data[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, cy + r * [Y_V1, Y_V2, Y_V3][row], _valueFont, data[0], just);
        dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, cy + r * [Y_L1, Y_L2, Y_L3][row], _labelFont, data[1], just);
    }

    // ---------- Sunrise / sunset ----------

    private function drawSunTimes(dc, cx, cy, r) as Void {
        if (!(Toybox has :Weather) || !(Weather has :getSunrise)) { return; }
        var loc = null;
        if (Toybox has :Position) {
            var posInfo = Position.getInfo();
            if (posInfo != null) { loc = posInfo.position; }
        }
        if (loc == null) { return; }

        var today = Time.today();
        var sunrise = Weather.getSunrise(loc, today);
        var sunset = Weather.getSunset(loc, today);
        if (sunrise == null || sunset == null) { return; }

        var sr = Gregorian.info(sunrise, Time.FORMAT_SHORT);
        var ss = Gregorian.info(sunset, Time.FORMAT_SHORT);
        var settings = System.getDeviceSettings();
        var a = timeParts(sr.hour, sr.min, settings);
        var b = timeParts(ss.hour, ss.min, settings);
        var txt = a[0] + ":" + a[1] + "  " + b[0] + ":" + b[1];

        dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + r * Y_SUN, _labelFont, txt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---------- Status row ----------

    private function drawStatus(dc, cx, cy, r, settings) as Void {
        var items = [];
        if (_showNotif && settings.notificationCount != null) {
            items.add([0, settings.notificationCount]);
        }
        if (_showAlarms && (settings has :alarmCount) && settings.alarmCount != null) {
            items.add([2, settings.alarmCount]);
        }
        if (_showDnd && (settings has :doNotDisturb)) {
            items.add([3, settings.doNotDisturb ? 1 : 0]);
        }
        if (items.size() == 0) { return; }

        var font = _labelFont;
        var icon = r * ICON_SIZE;
        if (icon < 9) { icon = 9; }
        var pad = r * 0.03;
        var gap = r * ICON_GAP;

        var widths = new [items.size()];
        var total = gap * (items.size() - 1);
        for (var i = 0; i < items.size(); i++) {
            var w = icon;
            if (items[i][0] != 3) {
                w += pad + dc.getTextWidthInPixels(items[i][1].format("%d"), font);
            }
            widths[i] = w;
            total += w;
        }

        var x = cx - total / 2.0;
        var y = cy + r * Y_STATUS;
        for (var i = 0; i < items.size(); i++) {
            var kind = items[i][0];
            var n = items[i][1];
            var active = n > 0;

            if (kind == 0) {
                dc.setColor(active ? _accent : C_OFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + icon / 2.0, y, icon * 0.28);
            } else if (kind == 2) {
                drawAlarm(dc, x, y, icon, active ? C_ALARM : C_OFF);
            } else {
                drawMoon(dc, x, y, icon, active ? C_DND : C_OFF);
            }

            if (kind != 3) {
                dc.setColor(active ? C_WHITE : C_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x + icon + pad, y, font, n.format("%d"),
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
        var pen = s * 0.11;
        if (pen < 1.5) { pen = 1.5; }
        var ccx = x + s / 2.0;
        var ccy = y + s * 0.06;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen.toNumber() < 1 ? 1 : pen.toNumber());
        dc.drawCircle(ccx, ccy, s * 0.38);
        dc.drawLine(ccx, ccy, ccx, ccy - s * 0.2);
        dc.drawLine(ccx, ccy, ccx + s * 0.15, ccy);
        dc.fillCircle(x + s * 0.12, y - s * 0.36, s * 0.14);
        dc.fillCircle(x + s * 0.88, y - s * 0.36, s * 0.14);
    }

    // ---------- Always-on (low power) ----------

    // As in ApexFace: the 12 hour ticks, the date and a thin time with the
    // minutes dimmed, all shifted each minute against burn-in. Nothing accent-coloured.
    private function drawAod(dc, cx, cy, r, clock, settings) as Void {
        // FaceCore burn-in drift (design px of the 454 screen, scaled to this one)
        var s = FaceKit.aodShift(clock.min);
        var dx = s[0] * r / FaceKit.C;
        var dy = s[1] * r / FaceKit.C;

        // Ticks inset by the largest shift so they stay on the round screen
        var pen = (r * 0.013).toNumber();
        dc.setPenWidth(pen < 1 ? 1 : pen);
        dc.setColor(C_AOD_TICK, Graphics.COLOR_TRANSPARENT);
        var rIn = r * (0.94 - AOD_SHIFT * 1.42);
        var rOut = r * (0.99 - AOD_SHIFT * 1.42);
        for (var i = 0; i < 12; i++) {
            var a = Math.toRadians(i * 30);
            var sx = Math.sin(a);
            var cy0 = -Math.cos(a);
            dc.drawLine(cx + dx + rIn * sx, cy + dy + rIn * cy0, cx + dx + rOut * sx, cy + dy + rOut * cy0);
        }
        dc.setPenWidth(1);

        // Hours (with the colon) in grey, minutes dimmer
        var t = timeParts(clock.hour, clock.min, settings);
        var head = t[0] + ":";
        var wHead = dc.getTextWidthInPixels(head, _aodFont);
        var x = cx + dx - (wHead + dc.getTextWidthInPixels(t[1], _aodFont)) / 2.0;
        var y = cy + dy;
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_AOD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _aodFont, head, just);
        dc.setColor(C_AOD_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + wHead, y, _aodFont, t[1], just);

        if (_aodDate && _dateFormat != DF_OFF) {
            dc.setColor(C_AOD_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + dx, cy + dy - r * 0.34, _dateFont, dateString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
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
        dc.setPenWidth(1);
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

    // ---------- Helpers ----------

    private function shortNumber(n as Number) as String {
        if (n >= 1000) {
            return (n / 1000.0).format("%.1f") + "k";
        }
        return n.format("%d");
    }
}
