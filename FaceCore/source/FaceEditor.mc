import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Garmin's native on-device watch face editor (Watch Face Configurations, API 5.1+;
// each face's resources-fr970/configs/watchface.xml). FaceCoreView applies the editor's
// choices on top of the phone settings: the editor wins when it has a value.
module FaceEditor {

    // The active configuration's settings, or null on watches without the editor.
    function settingsFor(configId as Application.WatchFaceConfig.Id or Null) as Application.WatchFaceConfig.Settings or Null {
        if (!(Application has :WatchFaceConfig)) {
            return null;
        }
        try {
            return Application.WatchFaceConfig.getSettings(configId);
        } catch (e) {
            return null;
        }
    }
}

class FaceEditorDelegate extends WatchUi.WatchFaceDelegate {

    private var mView as FaceCoreView;

    function initialize(view as FaceCoreView) {
        WatchFaceDelegate.initialize();
        mView = view;
    }

    function onWatchFaceConfigEdited(options as {
            :configId as Application.WatchFaceConfig.Id,
            :type as WatchUi.WatchFaceConfigType or Null,
            :committed as Boolean }) as Void {
        var settings = FaceEditor.settingsFor(options[:configId]);
        if (settings != null) {
            mView.applyEditor(settings);
            WatchUi.requestUpdate();
        }
    }
}
