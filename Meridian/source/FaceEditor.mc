import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Garmin's native on-device watch face editor (Watch Face Configurations, API 5.1+;
// resources-fr970/configs/watchface.xml). The face offers a style and an accent
// colour there; the view applies them on top of the phone settings.
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

    // A setting that both the phone app and the editor can change: the side that changed it
    // last wins. Storage remembers both values per key ([phone, editor, editor wins]). On the
    // first run the editor wins only if it was moved off the default and the phone wasn't.
    function pick(key as String, phone as Number, editor as Number or Null, fallback as Number) as Number {
        if (editor == null) {
            return phone;
        }
        var editorWins = false;
        try {
            var seen = Application.Storage.getValue(key);
            if (seen instanceof Array && seen.size() == 3) {
                if (phone != seen[0]) {
                    editorWins = false;
                } else if (editor != seen[1]) {
                    editorWins = true;
                } else {
                    editorWins = seen[2] == true;
                }
            } else {
                editorWins = editor != fallback && phone == fallback;
            }
            Application.Storage.setValue(key, [phone, editor, editorWins] as Array<Application.PropertyValueType>);
        } catch (e) {
            editorWins = false;
        }
        return editorWins ? editor : phone;
    }
}

class FaceEditorDelegate extends WatchUi.WatchFaceDelegate {

    private var mView as FaceView;

    function initialize(view as FaceView) {
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
