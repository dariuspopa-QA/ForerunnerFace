import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Garmin's native on-device watch face editor (Watch Face Configurations, API 5.1+;
// each face's resources-fr970/configs/watchface.xml). FaceCoreView applies the editor's
// choices on top of the phone settings: the editor wins when it has a value. Faces that
// want "whichever side changed it last wins" instead use pick() (Meridian).
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
                if (!phone.equals(seen[0])) {
                    editorWins = false;
                } else if (!editor.equals(seen[1])) {
                    editorWins = true;
                } else {
                    editorWins = seen[2] instanceof Boolean && seen[2] as Boolean;
                }
            } else {
                editorWins = editor != fallback && phone == fallback;
            }
            Application.Storage.setValue(key, [phone, editor, editorWins] as Array<Application.Storage.ValueType>);
        } catch (e) {
            editorWins = false;
        }
        return editorWins ? editor : phone;
    }
}
