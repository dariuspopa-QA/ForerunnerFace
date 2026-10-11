import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Passes on-watch editor changes to the face (FaceCoreApp adds it to every FaceCoreView face).
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
