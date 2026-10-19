import Toybox.Application;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// A bike ride app whose pages change on a wrist twist. Connect IQ can't drive the built-in
// Bike activity's pages, so this app records the ride itself and hosts its own pages.
class TwistSwitchApp extends Application.AppBase {

    const SAMPLE_RATE = 25;

    var ride as Ride = new Ride();
    var track as Track = new Track();
    var detector as TwistDetector = new TwistDetector(TwistDetector.DEFAULT_ANGLE, TwistDetector.DEFAULT_PAIR);
    var pager as Pager?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        applySettings();
        pager = new Pager(ride, detector);
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE] as Array<SensorType>);
        Sensor.registerSensorDataListener(method(:onSensorData), {
            :period => 1,
            :accelerometer => { :enabled => true, :sampleRate => SAMPLE_RATE }
        });
    }

    function onStop(state as Dictionary?) as Void {
        Sensor.unregisterSensorDataListener();
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        if (_switchTimer != null) {
            (_switchTimer as Timer.Timer).stop();
        }
        // No save here: a ride is only saved when Save is picked in the pause menu.
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return (pager as Pager).initialView();
    }

    function onSettingsChanged() as Void {
        applySettings();
        WatchUi.requestUpdate();
    }

    // Feeds the map page's breadcrumb. Poor fixes are skipped so the track doesn't jump about.
    function onPosition(info as Position.Info) as Void {
        try {
            var loc = info.position;
            if (loc == null || info.accuracy < Position.QUALITY_USABLE) {
                return;
            }
            var deg = loc.toDegrees();
            track.onFix(deg[0].toFloat(), deg[1].toFloat(), ride.isRecording());
        } catch (e) {
            noteError("gps", e);
        }
    }

    // The sensor callback doesn't change the view itself: it flags the switch and a one-shot
    // timer does it right after, outside the sensor callback.
    // Errors are caught, counted on screen and printed to GARMIN\Apps\LOGS\TwistSwitch.TXT
    // (println lands there when that file exists).
    var sensorBatches as Number = 0;
    var sensorErrors as Number = 0;
    private var _switchTimer as Timer.Timer?;

    function onSensorData(data as Sensor.SensorData) as Void {
        try {
            var a = data.accelerometerData;
            if (a == null || a.x == null || a.y == null || a.z == null) {
                return;
            }
            sensorBatches++;
            if (sensorBatches == 1) {
                System.println("accel first batch: " + a.x.size() + " samples, x0=" + a.x[0]);
            }
            var fired = detector.feed(a.x, a.y, a.z, 1000 / SAMPLE_RATE);
            if (fired > 0) {
                System.println("switch at twists=" + detector.twists);
                if (_switchTimer == null) {
                    _switchTimer = new Timer.Timer();
                }
                var t = _switchTimer as Timer.Timer;
                t.stop();
                t.start(method(:doSwitch), 50, false);
            }
        } catch (e) {
            noteError("sensor", e);
        }
    }

    function doSwitch() as Void {
        try {
            buzz();
        } catch (e) {
            noteError("vibrate", e);
        }
        try {
            if (pager != null) {
                (pager as Pager).show(1);
            }
        } catch (e) {
            noteError("switch", e);
        }
    }

    function noteError(where as String, e as Exception) as Void {
        sensorErrors++;
        System.println(where + " error " + sensorErrors + ": " + e.getErrorMessage());
        e.printStackTrace();
    }

    private function applySettings() as Void {
        var angle = Properties.getValue("TwistAngle");
        detector.setAngle(angle instanceof Number ? angle : TwistDetector.DEFAULT_ANGLE);
        var pair = Properties.getValue("PairTwists");
        detector.setPair(pair instanceof Boolean ? pair : TwistDetector.DEFAULT_PAIR);
    }

    private function buzz() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(60, 80)]);
        }
    }
}

function getApp() as TwistSwitchApp {
    return Application.getApp() as TwistSwitchApp;
}

function showDebug() as Boolean {
    var v = Application.Properties.getValue("ShowDebug");
    return v instanceof Boolean ? v : true;
}
