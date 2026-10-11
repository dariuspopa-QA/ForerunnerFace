import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// App entry and watch face editor wiring.

(:test)
function normalLaunchHasNoEditorDelegate(logger as Logger) as Boolean {
    var app = new ApexFaceApp();
    app.onStart(null);
    var views = app.getInitialView();
    ApexTestUtil.assertEqual(views.size(), 1);
    Test.assert(views[0] instanceof ApexFaceView);

    app.onStart({:launchedFromWatchFaceSettingsEditor => false});
    ApexTestUtil.assertEqual(app.getInitialView().size(), 1);
    return true;
}

(:test)
function editorLaunchAddsEditorDelegate(logger as Logger) as Boolean {
    var app = new ApexFaceApp();
    app.onStart({:launchedFromWatchFaceSettingsEditor => true});
    var views = app.getInitialView() as Array<Object>;
    ApexTestUtil.assertEqual(views.size(), 2);
    Test.assert(views[0] instanceof ApexFaceView);
    Test.assert(views[1] instanceof ApexEditorDelegate);
    return true;
}

(:test)
function settingsChangedReloadsWithoutError(logger as Logger) as Boolean {
    var app = new ApexFaceApp();
    app.onSettingsChanged();     // before a view exists
    app.onStart(null);
    app.getInitialView();
    app.onSettingsChanged();
    return true;
}

(:test)
function editorSettingsAreReadSafely(logger as Logger) as Boolean {
    var settings = FaceEditor.settingsFor(null);
    if (Application has :WatchFaceConfig) {
        logger.debug("editor configuration: " + (settings != null ? "present" : "none"));
    } else {
        ApexTestUtil.assertEqual(settings, null);
    }
    return true;
}

// The editor's slot ids must match resources/configs/watchface.xml (1-3 fields, 4 arc).
(:test)
function editorSlotIdsMatchTheConfig(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexEditor.SLOT_FIELD_1, 1);
    ApexTestUtil.assertEqual(ApexEditor.SLOT_ARC, 4);
    return true;
}
