import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Lang;

// The FIT recording: a normal cycling activity that lands in Garmin Connect when saved.
class Ride {

    private var _session as ActivityRecording.Session?;

    function initialize() {
    }

    function isOpen() as Boolean {
        return _session != null;
    }

    function isRecording() as Boolean {
        return _session != null && (_session as ActivityRecording.Session).isRecording();
    }

    function start() as Void {
        if (_session == null) {
            _session = ActivityRecording.createSession({
                :name => "Ride",
                :sport => Activity.SPORT_CYCLING
            });
        }
        (_session as ActivityRecording.Session).start();
    }

    function pause() as Void {
        if (isRecording()) {
            (_session as ActivityRecording.Session).stop();
        }
    }

    function lap() as Void {
        if (isRecording()) {
            (_session as ActivityRecording.Session).addLap();
        }
    }

    function save() as Void {
        if (_session != null) {
            var s = _session as ActivityRecording.Session;
            if (s.isRecording()) {
                s.stop();
            }
            s.save();
            _session = null;
        }
    }

    function discard() as Void {
        if (_session != null) {
            var s = _session as ActivityRecording.Session;
            if (s.isRecording()) {
                s.stop();
            }
            s.discard();
            _session = null;
        }
    }
}
