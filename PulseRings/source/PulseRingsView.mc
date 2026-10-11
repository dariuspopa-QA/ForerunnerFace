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
const C_TRACK   = 0x1F1F21;
const C_ALARM   = 0xFFB340;
const C_DND     = 0xA78BFA;
const C_AOD     = 0x9A9A9F;
const C_BG_GRAY = 0xB0B0B8;

// Body Battery ring color bands, matching Garmin's own convention.
const BB_LOW    = 0xFF453A; // < 25
const BB_MED    = 0xFFB340; // < 50
const BB_HIGH   = 0xF2E205; // < 75
const BB_FULL   = 0xB6F24A; // >= 75

const BG_LEVELS = [0.14, 0.24, 0.36];

// ---------- Layout (fractions of screen radius, from center) ----------
const Y_STATUS   = -0.66;
const Y_DATE     = -0.44;
const Y_TIME     = -0.06;
const Y_VALUE    =  0.42;
const Y_LABEL    =  0.56;
const Y_SUN      =  0.70;
const RING_OUT_R = 0.94;
const RING_IN_R  = 0.80;
const RING_PEN   = 0.026;
const TIME_SIZE  = 0.50;
const AOD_SIZE   = 0.38;
const ICON_SIZE  = 0.082;
const ICON_GAP   = 0.075;

// DateFormat setting (as in ApexFace): follow the watch (order from its distance units),
// "MON 28 SEP", "MON 28-09-2026", "MON 09-28-2026", or no date
const DF_WATCH = 0;
const DF_NAMED = 1;
const DF_DMY   = 2;
const DF_MDY   = 3;
const DF_OFF   = 4;

class PulseRingsView extends WatchUi.WatchFace {

    // Settings
    private var _accent = 0xB6F24A;
    private var _bgStyle = 0;
    private var _bgIntensity = 0;
    private var _bgColorMode = 0;
    private var _clockMode = 0;
    private var _timeWeight = 0;
    private var _dateFormat = 0;
    private var _field1 = 0;
    private var _field2 = 5;
    private var _showNotif = true;
    private var _showAlarms = true;
    private var _showDnd = true;
    private var _showSun = true;
    private var _aodDate = true;

    // State
    private var _awake = true;
    private var _fontsReady = false;
    private var _timeFont = Graphics.FONT_NUMBER_THAI_HOT;
    private var _aodFont = Graphics.FONT_NUMBER_HOT;
    private var _labelFont = Graphics.FONT_XTINY;
    private var _dateFont = Graphics.FONT_TINY;
    private var _valueFont = Graphics.FONT_SMALL;

    // Native watch face editor (see EditorConfig.mc).
    // Slots: 1 = left field, 2 = right field.
    private var _editMode = false;
    private var _editingSlot = null;
    private var _fieldIds = [null, null];  // system data field shown instead of a built-in one
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
        _timeWeight  = prop("TimeWeight", 0);
        _dateFormat  = prop("DateFormat", 0);
        _field1      = prop("Field1", 0);
        _field2      = prop("Field2", 5);
        _showNotif   = prop("ShowNotifications", true);
        _showAlarms  = prop("ShowAlarms", true);
        _showDnd     = prop("ShowDnd", true);
        _showSun     = prop("ShowSunTimes", true);
        _aodDate     = prop("AodShowDate", true);
        _fontsReady  = false;
        applyEditor(editorSettings(null), null);
    }

    // ---------- Native watch face editor ----------
    // Style = background pattern, Data = the two fields, Accent = accent color.

    function applyEditor(s, editedType) as Void {
        if (s == null) {
            return;
        }
        if (s.styleId != null && s.styleId >= 1 && s.styleId <= 7) {
            _bgStyle = s.styleId - 1;
        }
        if (s.accentColor != null && s.accentColor.color != null) {
            _accent = s.accentColor.color;
        }
        var refs = s.complicationSettings;
        if (refs != null) {
            for (var i = 0; i < refs.size(); i++) {
                var slot = refs[i].uniqueIdentifier;
                if (slot == 1 || slot == 2) {
                    var id = refs[i].complicationId;
                    var type = complicationType(id);
                    var kind = fieldKindFor(type);
                    if (kind != null) {
                        if (slot == 1) { _field1 = kind; } else { _field2 = kind; }
                    }
                    _fieldIds[slot - 1] = (type != null && kind == null) ? id : null;
                }
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

    // Built-in field for a data type the face already draws itself.
    private function fieldKindFor(type) as Number or Null {
        if (type == Complications.COMPLICATION_TYPE_HEART_RATE) { return 0; }
        if (type == Complications.COMPLICATION_TYPE_STRESS) { return 1; }
        if (type == Complications.COMPLICATION_TYPE_RECOVERY_TIME) { return 2; }
        if (type == Complications.COMPLICATION_TYPE_CALORIES) { return 3; }
        if (type == Complications.COMPLICATION_TYPE_BATTERY) { return 4; }
        if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) { return 5; }
        if (type == Complications.COMPLICATION_TYPE_STEPS) { return 6; }
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
        if (_r == 0.0 || (slot != 1 && slot != 2)) {
            return null;
        }
        var r = _r;
        var x = _cx + (slot == 1 ? -1 : 1) * r * 0.28;
        return [(x - r * 0.24).toNumber(), (_cy + r * (Y_VALUE - 0.10)).toNumber(),
            (r * 0.48).toNumber(), (r * (Y_LABEL - Y_VALUE + 0.18)).toNumber()];
    }

    function slotAt(x, y) as Number or Null {
        for (var slot = 1; slot <= 2; slot++) {
            var b = slotBox(slot);
            if (b != null && x >= b[0] && x <= b[0] + b[2] && y >= b[1] && y <= b[1] + b[3]) {
                return slot;
            }
        }
        return null;
    }

    function drawSlot(dc, slot) as Void {
        if (!_fontsReady) { buildFonts(dc); }
        drawField(dc, _cx, _cy, _r, slot);
    }

    // ---------- Fonts ----------

    private function buildFonts(dc as Dc) as Void {
        var w = dc.getWidth();
        var r = w / 2.0;
        _timeFont = Graphics.FONT_NUMBER_THAI_HOT;
        _aodFont = Graphics.FONT_NUMBER_HOT;
        _labelFont = Graphics.FONT_XTINY;
        _dateFont = Graphics.FONT_TINY;
        _valueFont = Graphics.FONT_SMALL;
        if (Graphics has :getVectorFont) {
            var faces;
            if (_timeWeight == 0) {
                faces = ["RobotoCondensedLight", "RobotoLight", "RobotoCondensedRegular", "RobotoRegular"];
            } else if (_timeWeight == 1) {
                faces = ["RobotoCondensedRegular", "RobotoRegular"];
            } else {
                faces = ["RobotoCondensedBold", "RobotoBold", "RobotoCondensedRegular"];
            }
            var f = Graphics.getVectorFont({ :face => faces, :size => (r * TIME_SIZE).toNumber() });
            if (f != null) { _timeFont = f; }
            var a = Graphics.getVectorFont({ :face => ["RobotoCondensedLight", "RobotoCondensedRegular", "RobotoRegular"], :size => (r * AOD_SIZE).toNumber() });
            if (a != null) { _aodFont = a; }

            var textFaces = ["RobotoCondensedRegular", "RobotoRegular"];
            var l = Graphics.getVectorFont({ :face => textFaces, :size => (dc.getFontHeight(Graphics.FONT_XTINY) * 0.8).toNumber() });
            if (l != null) { _labelFont = l; }
            var d = Graphics.getVectorFont({ :face => textFaces, :size => (dc.getFontHeight(Graphics.FONT_TINY) * 0.8).toNumber() });
            if (d != null) { _dateFont = d; }
            var v = Graphics.getVectorFont({ :face => textFaces, :size => (dc.getFontHeight(Graphics.FONT_SMALL) * 0.8).toNumber() });
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
        if (!_awake && burnIn) {
            drawAod(dc, cx, cy, r, clock, settings);
            return;
        }

        drawBackground(dc, cx, cy, r);
        drawRings(dc, cx, cy, r);
        drawStatus(dc, cx, cy, r, settings);
        if (_dateFormat != DF_OFF) {
            dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + r * Y_DATE, _dateFont, dateString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        drawTime(dc, cx, cy + r * Y_TIME, r, clock, settings, _timeFont, C_WHITE);
        drawFields(dc, cx, cy, r);
        if (_showSun) {
            drawSunTimes(dc, cx, cy, r);
        }
    }

    // ---------- Time and date ----------

    private function timeParts(clock, settings) as Array {
        var hour = clock.hour;
        var use24 = (_clockMode == 0) ? settings.is24Hour : (_clockMode == 1);
        if (use24) {
            return [hour.format("%02d") + ":" + clock.min.format("%02d"), ""];
        }
        var suffix = (hour < 12) ? "AM" : "PM";
        hour = hour % 12;
        if (hour == 0) { hour = 12; }
        return [hour.format("%d") + ":" + clock.min.format("%02d"), suffix];
    }

    private function drawTime(dc, cx, y, r, clock, settings, font, color) as Void {
        var parts = timeParts(clock, settings);
        var t = parts[0];
        var suffix = parts[1];
        var small = _labelFont;
        var gap = r * 0.03;
        var tw = dc.getTextWidthInPixels(t, font);
        var sw = (suffix.length() > 0) ? dc.getTextWidthInPixels(suffix, small) + gap : 0;
        var x = cx - sw / 2.0;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, t, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (suffix.length() > 0) {
            var fh = dc.getFontHeight(font);
            dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + tw / 2.0 + gap, y + fh * 0.22, small, suffix,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Weekday and date by the DateFormat setting: "MON 28 SEP", or day and month padded
    // "MON 28-09-2026" / "MON 09-28-2026". Watch picks the numeric order from the
    // distance units (Connect IQ has no API for the watch's date order): miles = month first.
    private function dateString() as String {
        var m = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var weekday = m.day_of_week.toUpper() + " ";
        var format = _dateFormat;
        if (format != DF_NAMED && format != DF_DMY && format != DF_MDY) {
            format = (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE) ? DF_MDY : DF_DMY;
        }
        if (format != DF_NAMED) {
            var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var day = d.day.format("%02d");
            var month = d.month.format("%02d");
            return weekday + (format == DF_DMY ? day + "-" + month : month + "-" + day) + "-" + d.year;
        }
        return weekday + m.day.format("%d") + " " + m.month.toUpper();
    }

    // ---------- Rings ----------
    // Outer ring: step progress (accent color).
    // Inner ring: current Body Battery level, colored by Garmin's own convention.

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

    private function drawArcRing(dc, cx, cy, rr, pen, pct, color) as Void {
        dc.setPenWidth(pen.toNumber());
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rr);

        if (pct > 0.0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            if (pct >= 0.999) {
                dc.drawCircle(cx, cy, rr);
            } else {
                var end = 90.0 - 360.0 * pct;
                if (end < 0) { end += 360.0; }
                dc.drawArc(cx, cy, rr, Graphics.ARC_CLOCKWISE, 90, end);
                var cap = pen / 2.0;
                dc.fillCircle(cx, cy - rr, cap);
                var a = Math.toRadians(end);
                dc.fillCircle(cx + rr * Math.cos(a), cy - rr * Math.sin(a), cap);
            }
        }
    }

    private function drawRings(dc, cx, cy, r) as Void {
        var pen = r * RING_PEN;
        if (pen < 3) { pen = 3; }

        var am = ActivityMonitor.getInfo();
        var stepPct = 0.0;
        if (am.steps != null && am.stepGoal != null && am.stepGoal > 0) {
            stepPct = am.steps.toFloat() / am.stepGoal;
        }
        if (stepPct > 1.0) { stepPct = 1.0; }
        drawArcRing(dc, cx, cy, r * RING_OUT_R, pen, stepPct, _accent);

        var bb = bodyBatteryLevel();
        var bbPct = (bb == null) ? 0.0 : bb / 100.0;
        if (bbPct > 1.0) { bbPct = 1.0; }
        if (bbPct < 0.0) { bbPct = 0.0; }
        var bbColor = BB_LOW;
        if (bb != null) {
            if (bb >= 75) { bbColor = BB_FULL; }
            else if (bb >= 50) { bbColor = BB_HIGH; }
            else if (bb >= 25) { bbColor = BB_MED; }
        }
        drawArcRing(dc, cx, cy, r * RING_IN_R, pen, bbPct, bbColor);

        dc.setPenWidth(1);
    }

    // ---------- Data fields ----------

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

    private function currentStress() as Number or Null {
        var am = ActivityMonitor.getInfo();
        if (am has :stressScore && am.stressScore != null) {
            return am.stressScore;
        }
        return null;
    }

    // Returns [value, label]
    private function fieldData(kind) as Array {
        if (kind == 0) {
            var hr = heartRate();
            return [hr == null ? "--" : hr.format("%d"), "BPM"];
        } else if (kind == 1) {
            var st = currentStress();
            return [st == null ? "--" : st.format("%d"), "STRESS"];
        } else if (kind == 2) {
            var am = ActivityMonitor.getInfo();
            var rec = (am has :timeToRecovery) ? am.timeToRecovery : null;
            return [rec == null ? "--" : rec.format("%d") + "h", "RECOVERY"];
        } else if (kind == 3) {
            var cal = ActivityMonitor.getInfo().calories;
            return [cal == null ? "--" : cal.format("%d"), "KCAL"];
        } else if (kind == 4) {
            return [System.getSystemStats().battery.toNumber().format("%d") + "%", "BATTERY"];
        } else if (kind == 5) {
            var bb = bodyBatteryLevel();
            return [bb == null ? "--" : bb.format("%d"), "BODY"];
        }
        var steps = ActivityMonitor.getInfo().steps;
        return [shortNumber(steps == null ? 0 : steps), "STEPS"];
    }

    private function drawFields(dc, cx, cy, r) as Void {
        dc.setColor(C_OFF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx, cy + r * 0.34, cx, cy + r * 0.63);
        for (var slot = 1; slot <= 2; slot++) {
            if (_editingSlot != slot) {
                drawField(dc, cx, cy, r, slot);
            }
        }
    }

    // Slot 1 = left, 2 = right. Shows a built-in field, or the system data
    // field picked in the watch face editor.
    private function drawField(dc, cx, cy, r, slot) as Void {
        var id = _fieldIds[slot - 1];
        var data;
        if (id != null) {
            var ct = complicationText(id);
            data = (ct == null) ? ["--", ""] : ct;
        } else {
            data = fieldData(slot == 1 ? _field1 : _field2);
        }
        var just = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var x = cx + (slot == 1 ? -1 : 1) * r * 0.28;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, cy + r * Y_VALUE, _valueFont, data[0], just);
        dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, cy + r * Y_LABEL, _labelFont, data[1], just);
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
        var txt = sr.hour.format("%02d") + ":" + sr.min.format("%02d") + "  " +
                  ss.hour.format("%02d") + ":" + ss.min.format("%02d");

        dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + r * Y_SUN, _labelFont, txt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---------- Status row ----------
    // Item kinds: 0 notifications, 2 alarms, 3 do not disturb

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
        if (icon < 10) { icon = 10; }
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

    // Real crescent polygon (no black cut-out, so it works over backgrounds)
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

    private function drawAod(dc, cx, cy, r, clock, settings) as Void {
        var shifts = [[0, 0], [1, 1], [-1, 1], [1, -1], [-1, -1]];
        var s = shifts[clock.min % shifts.size()];
        var dx = s[0] * r * 0.06;
        var dy = s[1] * r * 0.06;

        drawTime(dc, cx + dx, cy + dy, r, clock, settings, _aodFont, C_AOD);

        if (_aodDate && _dateFormat != DF_OFF) {
            dc.setColor(C_OFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + dx, cy + dy - r * 0.34, _labelFont, dateString(),
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
