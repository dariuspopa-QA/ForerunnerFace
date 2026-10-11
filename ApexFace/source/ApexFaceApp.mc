import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ApexFaceApp extends Application.AppBase {

    private var mView as ApexFaceView or Null;
    private var mEditMode as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    // The watch face editor launches the face with a flag in the start state.
    function onStart(state as Dictionary?) as Void {
        mEditMode = false;
        if (state != null && state[:launchedFromWatchFaceSettingsEditor] == true) {
            mEditMode = true;
        }
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new ApexFaceView(mEditMode);
        mView = view;
        if (mEditMode) {
            return [view, new ApexEditorDelegate(view)];
        }
        return [view];
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

function getApp() as ApexFaceApp {
    return Application.getApp() as ApexFaceApp;
}
