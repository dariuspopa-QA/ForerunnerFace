import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

// Field and arc metrics (ids match the tables in CLAUDE.md and the settings lists).
module ApexMetrics {

    enum {
        F_HR = 0,
        F_STEPS = 1,
        F_DISTANCE = 2,
        F_CALORIES = 3,
        F_FLOORS = 4,
        F_STRESS = 5,
        F_BODY_BATTERY = 6,
        F_READY = 7,       // No Training Readiness source on fr970; hidden from settings
        F_RECOVERY = 8,
        F_SUNRISE = 9,
        F_SUNSET = 10,
        F_ALTITUDE = 11,
        F_TEMP = 12,
        F_BATTERY = 13,
        F_NOTIFS = 14,
        F_SEC = 15,
        F_EMPTY = 16
    }

    enum {
        A_BODY_BATTERY = 0,
        A_STEP_GOAL = 1,
        A_BATTERY = 2,
        A_STRESS = 3,
        A_READINESS = 4,   // Hidden from settings, as F_READY
        A_INTENSITY = 5,
        A_OFF = 6
    }

    const NO_VALUE = "--";

    // A field id from settings, or F_EMPTY when it is unknown or hidden (READY).
    function validField(id as Number) as Number {
        return (id < F_HR || id > F_EMPTY || id == F_READY) ? F_EMPTY : id;
    }

    // An arc id from settings, or A_OFF when it is unknown or hidden (READINESS).
    function validArc(id as Number) as Number {
        return (id < A_BODY_BATTERY || id > A_OFF || id == A_READINESS) ? A_OFF : id;
    }

    function clampFraction(f as Float) as Float {
        return f < 0.0f ? 0.0f : (f > 1.0f ? 1.0f : f);
    }

    // 0..100 reading as a 0..1 fraction, or null without a reading.
    function percentFraction(value as Number or Null) as Float or Null {
        return value != null ? clampFraction(value / 100.0f) : null;
    }

    // value / goal capped at 1, or null without a reading or a positive goal.
    function goalFraction(value as Number or Null, goal as Number or Null) as Float or Null {
        if (value == null || goal == null || goal <= 0) {
            return null;
        }
        return clampFraction(value.toFloat() / goal);
    }

    // Built-in field for a data type picked in the watch face editor, or null
    // when the face has no own source for it (it then shows the system value).
    function fieldForComplication(type as Complications.Type or Null) as Number or Null {
        if (type == null) {
            return null;
        }
        switch (type) {
            case Complications.COMPLICATION_TYPE_HEART_RATE: return F_HR;
            case Complications.COMPLICATION_TYPE_STEPS: return F_STEPS;
            case Complications.COMPLICATION_TYPE_CALORIES: return F_CALORIES;
            case Complications.COMPLICATION_TYPE_FLOORS_CLIMBED: return F_FLOORS;
            case Complications.COMPLICATION_TYPE_STRESS: return F_STRESS;
            case Complications.COMPLICATION_TYPE_BODY_BATTERY: return F_BODY_BATTERY;
            case Complications.COMPLICATION_TYPE_RECOVERY_TIME: return F_RECOVERY;
            case Complications.COMPLICATION_TYPE_SUNRISE: return F_SUNRISE;
            case Complications.COMPLICATION_TYPE_SUNSET: return F_SUNSET;
            case Complications.COMPLICATION_TYPE_ALTITUDE: return F_ALTITUDE;
            case Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE: return F_TEMP;
            case Complications.COMPLICATION_TYPE_BATTERY: return F_BATTERY;
            case Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT: return F_NOTIFS;
        }
        return null;
    }

    // Arc metric for a data type picked in the editor's arc slot.
    function arcForComplication(type as Complications.Type or Null) as Number or Null {
        if (type == null) {
            return null;
        }
        switch (type) {
            case Complications.COMPLICATION_TYPE_BODY_BATTERY: return A_BODY_BATTERY;
            case Complications.COMPLICATION_TYPE_STEPS: return A_STEP_GOAL;
            case Complications.COMPLICATION_TYPE_BATTERY: return A_BATTERY;
            case Complications.COMPLICATION_TYPE_STRESS: return A_STRESS;
            case Complications.COMPLICATION_TYPE_INTENSITY_MINUTES: return A_INTENSITY;
        }
        return null;
    }

    function fieldLabel(id as Number) as String {
        var settings = System.getDeviceSettings();
        switch (id) {
            case F_HR: return "HR";
            case F_STEPS: return "STEPS";
            case F_DISTANCE: return settings.distanceUnits == System.UNIT_STATUTE ? "MI" : "KM";
            case F_CALORIES: return "KCAL";
            case F_FLOORS: return "FLOORS";
            case F_STRESS: return "STRESS";
            case F_BODY_BATTERY: return "BODY BATT";
            case F_READY: return "READY";
            case F_RECOVERY: return "RECOVERY";
            case F_SUNRISE: return "SUNRISE";
            case F_SUNSET: return "SUNSET";
            case F_ALTITUDE: return settings.elevationUnits == System.UNIT_STATUTE ? "ALT FT" : "ALT M";
            case F_TEMP: return "TEMP";
            case F_BATTERY: return "BATTERY";
            case F_NOTIFS: return "NOTIFS";
            case F_SEC: return "SEC";
        }
        return "";
    }

    function arcLabel(id as Number) as String {
        switch (id) {
            case A_BODY_BATTERY: return "BODY BATT";
            case A_STEP_GOAL: return "STEP GOAL";
            case A_BATTERY: return "BATTERY";
            case A_STRESS: return "STRESS";
            case A_READINESS: return "READINESS";
            case A_INTENSITY: return "INTENSITY MIN";
        }
        return "";
    }

    // [value text, label] of a system data field picked in the watch face
    // editor that the face has no own source for (VO2 max, sleep score, ...).
    function complicationText(id as Complications.Id) as [String, String] {
        var c = null;
        try {
            c = Complications.getComplication(id);
        } catch (e) {
            return [NO_VALUE, ""];
        }
        var label = "";
        if (c.shortLabel != null) {
            label = (c.shortLabel as String).toUpper();
        } else if (c.longLabel != null) {
            label = (c.longLabel as String).toUpper();
        }
        return [ApexFormat.complicationValueText(c.value, c.unit), label];
    }
}

// Sensor readings for one screen update. Slow-changing values (history,
// weather, sun times) are read at most once per minute; heart rate and
// seconds are read on every update.
class ApexData {

    private var mMinuteKey as Number = -1;
    private var mInfo as ActivityMonitor.Info or Null;
    private var mHaveBodyBattery as Boolean = false;
    private var mBodyBattery as Number or Null;
    private var mHaveStress as Boolean = false;
    private var mStress as Number or Null;
    private var mHaveWeather as Boolean = false;
    private var mWeather as Weather.CurrentConditions or Null;
    private var mHaveSun as Boolean = false;
    private var mSunrise as Time.Moment or Null;
    private var mSunset as Time.Moment or Null;
    private var mTwelveHour as Boolean = false;

    function initialize() {
    }

    // Sunrise / sunset follow the face's 12 / 24 h time format.
    function setTwelveHour(twelve as Boolean) as Void {
        mTwelveHour = twelve;
    }

    // Call once per update; drops cached values when the minute changes.
    function refresh(clock as System.ClockTime) as Void {
        var key = clock.hour * 60 + clock.min;
        if (key != mMinuteKey) {
            mMinuteKey = key;
            mInfo = ActivityMonitor.getInfo();
            mHaveBodyBattery = false;
            mHaveStress = false;
            mHaveWeather = false;
            mHaveSun = false;
        }
    }

    // ---- Fields --------------------------------------------------------

    function fieldValue(id as Number, clock as System.ClockTime, awake as Boolean) as String {
        var info = mInfo;
        switch (id) {
            case ApexMetrics.F_HR:
                return ApexFormat.numberText(heartRate());
            case ApexMetrics.F_STEPS:
                return ApexFormat.thousandsText(info != null ? info.steps : null);
            case ApexMetrics.F_DISTANCE:
                return distance();
            case ApexMetrics.F_CALORIES:
                return ApexFormat.thousandsText(info != null ? info.calories : null);
            case ApexMetrics.F_FLOORS:
                return ApexFormat.numberText(info != null && (info has :floorsClimbed) ? info.floorsClimbed : null);
            case ApexMetrics.F_STRESS:
                return ApexFormat.numberText(stress());
            case ApexMetrics.F_BODY_BATTERY:
                return ApexFormat.numberText(bodyBattery());
            case ApexMetrics.F_RECOVERY:
                // Not every watch tracks recovery time (e.g. Venu 2, vivoactive 6): check the member exists
                return ApexFormat.recoveryText(info != null && (info has :timeToRecovery) ? info.timeToRecovery : null);
            case ApexMetrics.F_SUNRISE:
                return sunText(false);
            case ApexMetrics.F_SUNSET:
                return sunText(true);
            case ApexMetrics.F_ALTITUDE:
                return altitude();
            case ApexMetrics.F_TEMP:
                return temperature();
            case ApexMetrics.F_BATTERY:
                return ApexFormat.percentText(System.getSystemStats().battery);
            case ApexMetrics.F_NOTIFS:
                return ApexFormat.numberText(System.getDeviceSettings().notificationCount);
            case ApexMetrics.F_SEC:
                return awake ? ApexFormat.twoDigits(clock.sec) : ApexMetrics.NO_VALUE;
        }
        return ApexMetrics.NO_VALUE;
    }

    // ---- Arc -----------------------------------------------------------

    // Fill fraction 0..1, or null when there is no reading.
    function arcFraction(id as Number) as Float or Null {
        var info = mInfo;
        switch (id) {
            case ApexMetrics.A_BODY_BATTERY:
                return ApexMetrics.percentFraction(bodyBattery());
            case ApexMetrics.A_STEP_GOAL:
                return info != null ? ApexMetrics.goalFraction(info.steps, info.stepGoal) : null;
            case ApexMetrics.A_BATTERY:
                return ApexMetrics.clampFraction(System.getSystemStats().battery / 100.0f);
            case ApexMetrics.A_STRESS:
                return ApexMetrics.percentFraction(stress());
            case ApexMetrics.A_INTENSITY:
                return info != null && (info has :activeMinutesWeekGoal)
                    ? ApexMetrics.goalFraction(intensityMinutes(), info.activeMinutesWeekGoal) : null;
        }
        return null;
    }

    function arcReadout(id as Number) as String {
        switch (id) {
            case ApexMetrics.A_BODY_BATTERY:
                return ApexFormat.numberText(bodyBattery());
            case ApexMetrics.A_STEP_GOAL:
                var f = arcFraction(id);
                return ApexFormat.percentText(f != null ? f * 100 : null);
            case ApexMetrics.A_BATTERY:
                return ApexFormat.percentText(System.getSystemStats().battery);
            case ApexMetrics.A_STRESS:
                return ApexFormat.numberText(stress());
            case ApexMetrics.A_INTENSITY:
                return ApexFormat.numberText(intensityMinutes());
        }
        return ApexMetrics.NO_VALUE;
    }

    // ---- Sources -------------------------------------------------------

    private function heartRate() as Number or Null {
        var activity = Activity.getActivityInfo();
        if (activity != null && activity.currentHeartRate != null) {
            return activity.currentHeartRate;
        }
        var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
        if (sample != null && sample.heartRate != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            return sample.heartRate;
        }
        return null;
    }

    private function bodyBattery() as Number or Null {
        if (!mHaveBodyBattery) {
            mBodyBattery = latest(SensorHistory.getBodyBatteryHistory({:period => 1}));
            mHaveBodyBattery = true;
        }
        return mBodyBattery;
    }

    private function stress() as Number or Null {
        if (!mHaveStress) {
            var info = mInfo;
            mStress = (info != null && (info has :stressScore)) ? info.stressScore : null;
            if (mStress == null) {
                mStress = latest(SensorHistory.getStressHistory({:period => 1}));
            }
            mHaveStress = true;
        }
        return mStress;
    }

    private function intensityMinutes() as Number or Null {
        var info = mInfo;
        if (info == null || !(info has :activeMinutesWeek)) {
            return null;
        }
        var week = (info as ActivityMonitor.Info).activeMinutesWeek;
        return week != null ? (week as ActivityMonitor.ActiveMinutes).total : null;
    }

    private function distance() as String {
        var info = mInfo;
        return ApexFormat.distanceText(info != null ? info.distance : null,
            System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE);
    }

    private function altitude() as String {
        var metres = null;
        var activity = Activity.getActivityInfo();
        if (activity != null && activity.altitude != null) {
            metres = activity.altitude;
        } else {
            metres = latest(SensorHistory.getElevationHistory({:period => 1}));
        }
        return ApexFormat.altitudeText(metres, System.getDeviceSettings().elevationUnits == System.UNIT_STATUTE);
    }

    private function weather() as Weather.CurrentConditions or Null {
        if (!mHaveWeather) {
            mWeather = Weather.getCurrentConditions();
            mHaveWeather = true;
        }
        return mWeather;
    }

    private function temperature() as String {
        var conditions = weather();
        return ApexFormat.temperatureText(conditions != null ? conditions.temperature : null,
            System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE);
    }

    private function sunText(sunset as Boolean) as String {
        if (!mHaveSun) {
            mSunrise = null;
            mSunset = null;
            var conditions = weather();
            var location = conditions != null ? conditions.observationLocationPosition : null;
            if (location != null) {
                var now = Time.now();
                mSunrise = Weather.getSunrise(location, now);
                mSunset = Weather.getSunset(location, now);
            }
            mHaveSun = true;
        }
        var moment = sunset ? mSunset : mSunrise;
        if (moment == null) {
            return ApexMetrics.NO_VALUE;
        }
        var t = Gregorian.info(moment, Time.FORMAT_SHORT);
        return ApexFormat.clockText(t.hour as Number, t.min as Number, mTwelveHour);
    }

    // ---- Helpers -------------------------------------------------------

    private function latest(iterator as SensorHistory.SensorHistoryIterator or Null) as Number or Null {
        if (iterator == null) {
            return null;
        }
        var sample = iterator.next();
        if (sample == null || sample.data == null) {
            return null;
        }
        return (sample.data as Numeric).toNumber();
    }
}
