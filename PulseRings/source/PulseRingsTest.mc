import Toybox.Lang;
import Toybox.Test;

// PulseRings's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module PulseRingsTest {

    (:test)
    function drawsEveryMode(logger as Logger) as Boolean {
        FaceTestUtil.renderEveryMode(new PulseRingsView(false));
        // Inside the on-watch editor (never Always-On there)
        FaceTestUtil.renderEveryMode(new PulseRingsView(true));
        return true;
    }

    (:test)
    function drawsEverySettingValue(logger as Logger) as Boolean {
        var view = new PulseRingsView(false);
        FaceTestUtil.eachSettingValue(view, {
            "AccentColor" => [0, 1, 2, 3, 4],
            "BgStyle" => [0, 1, 2, 3, 4, 5, 6],
            "BgIntensity" => [0, 1, 2],
            "BgColor" => [0, 1],
            "TimeWeight" => [0, 1, 2],
            "DateFormat" => [0, 1, 2, 3, 4],
            "Field1" => [0, 1, 2, 3, 4, 5, 6],
            "Field2" => [0, 1, 2, 3, 4, 5, 6],
            "ShowNotifications" => [true, false],
            "ShowAlarms" => [true, false],
            "ShowDnd" => [true, false],
            "ShowSunTimes" => [true, false],
            "AodShowDate" => [true, false]
        }, view.method(:loadSettings), null);
        return true;
    }
}
