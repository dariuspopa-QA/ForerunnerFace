import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Per-watch checks for every FaceCoreView face, run on each screen size and API version by
// FaceCore/tools/run-device-tests.ps1 (the face's own tests draw every mode and setting).
(:test)
module FaceDeviceTest {

    // Every bitmap font of the face exists for this screen size (resources-round-<W>x<W>):
    // a missing one silently falls back to a system font of another size.
    (:test)
    function fontsLoadOnThisScreen(logger as Logger) as Boolean {
        var view = new FaceView(false);
        FaceTestUtil.render(view);
        logger.debug("screen " + System.getDeviceSettings().screenWidth + " px, fallbacks " + view.fontFallbacks);
        return view.fontFallbacks == 0;
    }

    // Awake, asleep (Always-On on AMOLED, the normal face once a minute on MIP) and awake
    // again, then inside the editor; the face keeps a working margin of free memory.
    (:test)
    function drawsWithinMemory(logger as Logger) as Boolean {
        var view = new FaceView(false);
        FaceTestUtil.renderEveryMode(view);
        FaceTestUtil.renderEveryMode(new FaceView(true));
        var stats = System.getSystemStats();
        logger.debug("used " + stats.usedMemory + " of " + stats.totalMemory);
        return stats.freeMemory > 8192;
    }
}
