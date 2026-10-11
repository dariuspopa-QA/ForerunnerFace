import Toybox.Lang;
import Toybox.Test;

// MinimalFace's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module MinimalFaceTest {

    (:test)
    function drawsEveryMode(logger as Logger) as Boolean {
        FaceTestUtil.renderEveryMode(new FaceView(false));
        // Inside the on-watch editor (never Always-On there)
        FaceTestUtil.renderEveryMode(new FaceView(true));
        return true;
    }

    (:test)
    function drawsEverySettingValue(logger as Logger) as Boolean {
        var view = new FaceView(false);
        FaceTestUtil.eachSettingValue(view, {
            "AccentColor" => [0, 1, 2, 3, 4],
            "BgStyle" => [0, 1, 2, 3, 4, 5, 6],
            "BgIntensity" => [0, 1, 2],
            "BgColor" => [0, 1],
            "ClockMode" => [0, 1, 2],
            "TimeWeight" => [0, 1, 2],
            "DateFormat" => [0, 1, 2, 3, 4],
            "RingMetric" => [0, 1, 2],
            "LeftField" => [0, 1, 2, 3],
            "RightField" => [0, 1, 2, 3],
            "ShowNotifications" => [true, false],
            "ShowMissedCalls" => [true, false],
            "ShowAlarms" => [true, false],
            "ShowDnd" => [true, false],
            "AodShowDate" => [true, false]
        }, view.method(:loadSettings), null);
        return true;
    }
}
