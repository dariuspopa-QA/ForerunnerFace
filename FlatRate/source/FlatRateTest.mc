import Toybox.Lang;
import Toybox.Test;

// FlatRate's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module FlatRateTest {

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
            "AccentColor" => [0xD7FF1F, 0xFFD400, 0xFF6A13, 0x3AD0FF],
            "DateFormat" => [0, 1, 2, 3],
            "ShiftStart" => [300, 330, 360, 390, 420, 450, 480, 510, 540, 570, 600, 630, 660],
            "ShiftLength" => [240, 360, 420, 480, 540, 600, 720],
            "BreakTime" => [-1, 600, 630, 660, 690, 720, 750, 780, 810, 840]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }
}
