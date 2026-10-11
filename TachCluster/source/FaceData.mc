import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.Weather;

// Sensor readings for the face (copied per project). Slow-changing values are
// read once a minute in refresh(); heart rate is read on every call. Every value
// may be null when the watch has no reading.
class FaceData {

    var steps as Number or Null;
    var stepGoal as Number or Null;
    var floors as Number or Null;
    var floorsGoal as Number or Null;
    var intensity as Number or Null;        // intensity minutes this week
    var intensityGoal as Number or Null;
    var recoveryHours as Number or Null;
    var bodyBattery as Number or Null;
    var stress as Number or Null;
    var temperature as Number or Null;      // in the watch's units
    var condition as Number or Null;        // Weather.CONDITION_*
    var sunrise as Float or Null;           // hours of the day, local time
    var sunset as Float or Null;
    var sleepTime as Float or Null;         // user profile bed / wake times, hours of the day
    var wakeTime as Float or Null;

    // Set only by the demo build (tools/demo/FaceDemo.mc)
    var hrOverride as Number or Null;
    var eventOverride as String or Null;
    var sleepOverride as Number or Null;
    var hrHoursOverride as Array<Number or Null> or Null;

    private var mMinute as Number = -1;
    private var mSavedLoc as String = "";
    private var mHrKey as Number = -1;
    private var mHrHours as Array<Number or Null> = new Array<Number or Null>[24];

    function initialize() {
    }

    // Re-reads the slow values when the minute changes; true if it did.
    function refresh() as Boolean {
        var clock = System.getClockTime();
        var minute = clock.hour * 60 + clock.min;
        if (minute == mMinute) {
            return false;
        }
        mMinute = minute;

        var info = ActivityMonitor.getInfo();
        steps = info.steps;
        stepGoal = info.stepGoal;
        floors = (info has :floorsClimbed) ? info.floorsClimbed : null;
        floorsGoal = (info has :floorsClimbedGoal) ? info.floorsClimbedGoal : null;
        intensity = null;
        if ((info has :activeMinutesWeek) && info.activeMinutesWeek != null) {
            intensity = (info.activeMinutesWeek as ActivityMonitor.ActiveMinutes).total;
        }
        intensityGoal = (info has :activeMinutesWeekGoal) ? info.activeMinutesWeekGoal : null;
        recoveryHours = (info has :timeToRecovery) ? info.timeToRecovery : null;

        bodyBattery = null;
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            bodyBattery = latest(SensorHistory.getBodyBatteryHistory({:period => 1}));
        }
        stress = (info has :stressScore) ? info.stressScore : null;
        if (stress == null && (Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
            stress = latest(SensorHistory.getStressHistory({:period => 1}));
        }

        readWeather();
        readSleepWindow();
        FaceDemo.apply(self);
        return true;
    }

    function heartRate() as Number or Null {
        if (hrOverride != null) {
            return hrOverride;
        }
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

    // value / goal as 0..1, or null without both.
    static function fraction(value as Number or Null, goal as Number or Null) as Float or Null {
        if (value == null || goal == null || goal <= 0) {
            return null;
        }
        return FaceKit.clamp01(value.toFloat() / goal);
    }

    // ---- Heart rate over the day ----------------------------------------

    // Highest heart rate in each of the last 24 clock hours, oldest first (the last
    // entry is the current hour), null where there is no reading. Rebuilt every ten
    // minutes from the sensor history and merged with what the face stored earlier,
    // so the day stays complete on watches that keep less than 24 h of history.
    function hrHours() as Array<Number or Null> {
        if (hrHoursOverride != null) {
            return hrHoursOverride as Array<Number or Null>;
        }
        var nowSec = Time.now().value();
        var key = nowSec / 600;
        if (key == mHrKey) {
            return mHrHours;
        }
        mHrKey = key;
        var clock = System.getClockTime();
        var hourStart = nowSec - clock.min * 60 - clock.sec;
        var hours = new Array<Number or Null>[24];

        if ((Toybox has :SensorHistory) && (SensorHistory has :getHeartRateHistory)) {
            var it = SensorHistory.getHeartRateHistory({
                :period => new Time.Duration(86400),
                :order => SensorHistory.ORDER_NEWEST_FIRST
            });
            var sample = it.next();
            while (sample != null) {
                var when = sample.when;
                var data = sample.data;
                if (when != null && data != null) {
                    var t = when.value();
                    var idx = t >= hourStart ? 23 : 22 - (hourStart - 1 - t) / 3600;
                    if (idx < 0) {
                        break;
                    }
                    var v = (data as Numeric).toNumber();
                    var old = hours[idx];
                    if (v > 0 && v < 255 && (old == null || v > old)) {
                        hours[idx] = v;
                    }
                }
                sample = it.next();
            }
        }

        // Stored: [hour start of the last entry, 24 values]
        try {
            var stored = Application.Storage.getValue("hrHours");
            if (stored instanceof Array && stored.size() == 2 && stored[0] instanceof Number && stored[1] instanceof Array) {
                var shift = (hourStart - (stored[0] as Number)) / 3600;
                var values = stored[1] as Array;
                for (var i = 0; i < 24; i++) {
                    var j = i + shift;
                    if (hours[i] == null && j >= 0 && j < 24 && j < values.size() && values[j] instanceof Number) {
                        hours[i] = values[j] as Number;
                    }
                }
            }
            Application.Storage.setValue("hrHours", [hourStart, hours] as Array<Application.PropertyValueType>);
        } catch (e) {
        }
        mHrHours = hours;
        return hours;
    }

    // ---- System data fields ----------------------------------------------

    // Time of the next calendar event ("18:30"), or null.
    function nextEvent() as String or Null {
        if (eventOverride != null) {
            return eventOverride;
        }
        var value = complicationValue(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
        return value instanceof String ? value : null;
    }

    // Last night's sleep score 0..100, or null (type 42 = COMPLICATION_TYPE_SLEEP_SCORE,
    // API 6.0.2; referenced by number so older watches still build).
    function sleepScore() as Number or Null {
        if (sleepOverride != null) {
            return sleepOverride;
        }
        var value = complicationValue(42 as Complications.Type);
        return value instanceof Number ? value : null;
    }

    private function complicationValue(type as Complications.Type) as Object or Null {
        if (!(Toybox has :Complications)) {
            return null;
        }
        try {
            return Complications.getComplication(new Complications.Id(type)).value;
        } catch (e) {
            return null;
        }
    }

    // ---- Weather and sun ------------------------------------------------

    // Short name of the current weather condition ("" if unknown).
    function conditionText() as String {
        var c = condition;
        if (c == null) {
            return "";
        }
        switch (c) {
            case Weather.CONDITION_CLEAR:
            case Weather.CONDITION_MOSTLY_CLEAR:
            case Weather.CONDITION_FAIR:
                return "Clear";
            case Weather.CONDITION_PARTLY_CLOUDY:
            case Weather.CONDITION_PARTLY_CLEAR:
                return "Partly cloudy";
            case Weather.CONDITION_MOSTLY_CLOUDY:
            case Weather.CONDITION_CLOUDY:
                return "Cloudy";
            case Weather.CONDITION_RAIN:
            case Weather.CONDITION_LIGHT_RAIN:
            case Weather.CONDITION_HEAVY_RAIN:
            case Weather.CONDITION_DRIZZLE:
            case Weather.CONDITION_UNKNOWN_PRECIPITATION:
                return "Rain";
            case Weather.CONDITION_SHOWERS:
            case Weather.CONDITION_LIGHT_SHOWERS:
            case Weather.CONDITION_HEAVY_SHOWERS:
            case Weather.CONDITION_SCATTERED_SHOWERS:
            case Weather.CONDITION_CHANCE_OF_SHOWERS:
                return "Showers";
            case Weather.CONDITION_SNOW:
            case Weather.CONDITION_LIGHT_SNOW:
            case Weather.CONDITION_HEAVY_SNOW:
            case Weather.CONDITION_WINTRY_MIX:
            case Weather.CONDITION_RAIN_SNOW:
            case Weather.CONDITION_LIGHT_RAIN_SNOW:
            case Weather.CONDITION_HEAVY_RAIN_SNOW:
                return "Snow";
            case Weather.CONDITION_THUNDERSTORMS:
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
            case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS:
                return "Storms";
            case Weather.CONDITION_FOG:
            case Weather.CONDITION_MIST:
            case Weather.CONDITION_HAZY:
            case Weather.CONDITION_HAZE:
                return "Fog";
            case Weather.CONDITION_WINDY:
                return "Windy";
        }
        return "";
    }

    private function readWeather() as Void {
        temperature = null;
        condition = null;
        sunrise = null;
        sunset = null;
        var conditions = Weather.getCurrentConditions();
        var location = null;
        if (conditions != null) {
            var t = conditions.temperature;
            if (t != null) {
                var deg = t.toFloat();
                if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                    deg = deg * 9 / 5 + 32;
                }
                temperature = Math.round(deg).toNumber();
            }
            condition = conditions.condition;
            location = conditions.observationLocationPosition;
        }
        location = sunLocation(location);
        if (location != null) {
            var now = Time.now();
            var rise = Weather.getSunrise(location, now);
            var set = Weather.getSunset(location, now);
            sunrise = rise != null ? hourOf(rise) : null;
            sunset = set != null ? hourOf(set) : null;
        }
    }

    // Where to compute sunrise and sunset: the weather observation, else the last
    // activity's GPS position, else the last place the face knew (stored).
    private function sunLocation(location as Position.Location or Null) as Position.Location or Null {
        if (location == null) {
            var activity = Activity.getActivityInfo();
            if (activity != null && activity.currentLocation != null) {
                location = activity.currentLocation;
            }
        }
        try {
            if (location != null) {
                var deg = location.toDegrees();
                var lat = deg[0].toFloat();
                var lon = deg[1].toFloat();
                var key = lat.format("%.2f") + "," + lon.format("%.2f");
                if (!key.equals(mSavedLoc)) {
                    mSavedLoc = key;
                    Application.Storage.setValue("sunLoc", [lat, lon] as Array<Application.PropertyValueType>);
                }
            } else {
                var stored = Application.Storage.getValue("sunLoc");
                if (stored instanceof Array && stored.size() == 2) {
                    location = new Position.Location({
                        :latitude => stored[0] as Float, :longitude => stored[1] as Float, :format => :degrees
                    });
                }
            }
        } catch (e) {
        }
        return location;
    }

    private function readSleepWindow() as Void {
        var profile = UserProfile.getProfile();
        var sleep = profile.sleepTime;
        var wake = profile.wakeTime;
        sleepTime = sleep != null ? ((sleep as Time.Duration).value() % 86400) / 3600.0f : null;
        wakeTime = wake != null ? ((wake as Time.Duration).value() % 86400) / 3600.0f : null;
    }

    private function hourOf(moment as Time.Moment) as Float {
        var t = Gregorian.info(moment, Time.FORMAT_SHORT);
        return (t.hour as Number) + (t.min as Number) / 60.0f;
    }

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
