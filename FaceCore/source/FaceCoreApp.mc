import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The app class every FaceCore face shares. The face's manifest entry names a
// three-line subclass that only says which view to build:
//
//   class SocketSetApp extends FaceCoreApp {
//       function initialize() { FaceCoreApp.initialize(); }
//       function createView(editMode as Boolean) as FaceCoreView { return new FaceView(editMode); }
//   }
class FaceCoreApp extends Application.AppBase {

    private var mView as FaceCoreView or Null;
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

    function createView(editMode as Boolean) as FaceCoreView {
        return new FaceCoreView(editMode, 0xFFFFFF);
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = createView(mEditMode);
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
