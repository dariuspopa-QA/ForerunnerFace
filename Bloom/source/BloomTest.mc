import Toybox.Lang;
import Toybox.Test;

// Bloom's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module BloomTest {

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
            "Palette" => [0, 1, 2, 3, 4, 5, 6, 7],
            "Highlight" => [0xFF8A3D, 0xFF4A4A, 0xFFD23D, 0xC8FF2E, 0x4FD1FF, 0xFF5AC8, 0xF3F1EC],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }
}
