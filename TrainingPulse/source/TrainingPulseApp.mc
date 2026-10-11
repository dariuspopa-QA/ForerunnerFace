import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TrainingPulseApp extends Application.AppBase {

    private var _view = null;
    private var _editMode = false;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        if (state != null && state[:launchedFromWatchFaceSettingsEditor] == true) {
            _editMode = true;
        }
    }

    function getInitialView() {
        _view = new TrainingPulseView(_editMode);
        if (_editMode) {
            return [ _view, new EditorDelegate(_view) ];
        }
        return [ _view ];
    }

    // Called when settings change in the Garmin Connect app
    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
