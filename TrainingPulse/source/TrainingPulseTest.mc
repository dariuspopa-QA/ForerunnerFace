import Toybox.Lang;
import Toybox.Test;

// TrainingPulse's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module TrainingPulseTest {

    (:test)
    function drawsEveryMode(logger as Logger) as Boolean {
        FaceTestUtil.renderEveryMode(new TrainingPulseView(false));
        // Inside the on-watch editor (never Always-On there)
        FaceTestUtil.renderEveryMode(new TrainingPulseView(true));
        return true;
    }

    (:test)
    function drawsEverySettingValue(logger as Logger) as Boolean {
        var view = new TrainingPulseView(false);
        FaceTestUtil.eachSettingValue(view, {
            "AccentColor" => [0, 1, 2, 3, 4],
            "BgStyle" => [0, 1, 2, 3, 4, 5, 6],
            "BgIntensity" => [0, 1, 2],
            "BgColor" => [0, 1],
            "ClockMode" => [0, 1, 2],
            "DateFormat" => [0, 1, 2, 3, 4],
            "Field1" => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "Field2" => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "Field3" => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "Field4" => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "Field5" => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "Field6" => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "ShowNotifications" => [true, false],
            "ShowAlarms" => [true, false],
            "ShowDnd" => [true, false],
            "ShowSunTimes" => [true, false],
            "AodShowDate" => [true, false]
        }, view.method(:loadSettings), null);
        return true;
    }
}
