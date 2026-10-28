import Toybox.Lang;
import Toybox.Test;

// Bearing's own tests: its drawing in every display mode and with every value of its phone
// setting, and the battery text. The shared core is tested in FaceCore/test.
(:test)
module BearingTest {

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
            "AccentColor" => [0x8CC8F0, 0x3DDC97, 0xF2B544, 0xFF6A3D]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    (:test)
    function batteryLevelAndText(logger as Logger) as Boolean {
        var view = new FaceView(false);
        var level = view.batteryLevel();
        Test.assert(level >= 0 && level <= 100);
        Test.assertEqual(view.batteryText(78), "78%");
        Test.assertEqual(view.batteryText(100), "100%");
        return true;
    }
}
