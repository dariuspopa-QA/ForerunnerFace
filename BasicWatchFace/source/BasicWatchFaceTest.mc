import Toybox.Lang;
import Toybox.Test;

// BasicWatchFace's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module BasicWatchFaceTest {

    (:test)
    function drawsEveryMode(logger as Logger) as Boolean {
        FaceTestUtil.renderEveryMode(new BasicWatchFaceView());
        return true;
    }

    (:test)
    function drawsEverySettingValue(logger as Logger) as Boolean {
        var view = new BasicWatchFaceView();
        FaceTestUtil.eachSettingValue(view, {
            "BackgroundColor" => [0x000000, 0x555555, 0xAAAAAA, 0xFFFFFF],
            "ForegroundColor" => [0x000000, 0x0000FF, 0xFF0000, 0xFFFFFF],
            "UseMilitaryFormat" => [true, false]
        }, view.method(:onShow), null);
        return true;
    }
}
