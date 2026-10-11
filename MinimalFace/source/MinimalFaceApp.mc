import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Annotated (:background) because the background service is created from here.
(:background)
class MinimalFaceApp extends Application.AppBase {

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
        _view = new FaceView(_editMode);
        if (_editMode) {
            return [ _view, new EditorDelegate(_view) ];
        }
        registerBackground();
        return [ _view ];
    }

    // Called when settings change in the Garmin Connect app
    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.loadSettings();
        }
        registerBackground();
        WatchUi.requestUpdate();
    }

    // Missed calls: a companion phone app sends { "missedCalls": n }
    private function registerBackground() as Void {
        var on = null;
        try {
            on = Application.Properties.getValue("ShowMissedCalls");
        } catch (e) {
            on = false;
        }
        if (on == true && (Toybox has :Background) && (Background has :registerForPhoneAppMessageEvent)) {
            Background.registerForPhoneAppMessageEvent();
        }
    }

    function getServiceDelegate() {
        return [ new MissedCallService() ];
    }

    function onBackgroundData(data) as Void {
        if (data instanceof Number) {
            Application.Storage.setValue("missedCalls", data);
            WatchUi.requestUpdate();
        }
    }
}
