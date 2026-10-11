import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ObdScannerApp extends Application.AppBase {

    private var mView as FaceView or Null;
    private var mEditMode as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    // The watch face editor launches the face with a flag in the start state.
    function onStart(state as Dictionary?) as Void {
        mEditMode = state != null && state[:launchedFromWatchFaceSettingsEditor] == true;
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new FaceView(mEditMode);
        mView = view;
        return [view, new FaceEditorDelegate(view)];
    }

    // New settings from the Garmin Connect app
    function onSettingsChanged() as Void {
        var view = mView;
        if (view != null) {
            view.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
