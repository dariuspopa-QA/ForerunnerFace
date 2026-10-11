import Toybox.Lang;
import Toybox.Test;

// Meridian's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module MeridianTest {

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
            "AccentColor" => [0xFF6A3D, 0x3DDC97, 0x4DA3FF, 0xF2F0EA, 0xF2B544, 0xFF5C8A],
            "RingMode" => [0, 1],
            "Focus" => [0, 1, 2, 3],
            "BottomLine" => [0, 1, 2, 3],
            "ShowSeconds" => [true, false],
            "AodRing" => [true, false],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }
}
