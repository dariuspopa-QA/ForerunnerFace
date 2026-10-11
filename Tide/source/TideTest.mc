import Toybox.Lang;
import Toybox.Test;

// Tide's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module TideTest {

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
            "AccentColor" => [0x3FD0C9, 0xFF7A59, 0xB8E05A, 0x8E9BFF],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }
}
