import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// What every face built on FaceCore shares: scale, sleep state, sensor data, settings
// (phone first, then the on-watch editor on top) and the Always-On decision. A face
// subclasses it as FaceView and only draws:
//
//   class FaceView extends FaceCoreView {
//       function initialize(editMode as Boolean) {
//           FaceCoreView.initialize(editMode, 0xFF6A13);   // default accent
//           loadSettings();
//       }
//       function loadFonts() as Void { ... FaceKit.loadFonts(ids, fallbacks) ... }
//       function onUpdate(dc as Dc) as Void { ... if (alwaysOn()) { ... aodShift(clock.min) ... } }
//   }
//
// Optional overrides: loadPhoneSettings() for the face's own properties, applyEditor()
// for editor choices beyond the accent colour (call FaceCoreView.applyEditor first).
class FaceCoreView extends WatchUi.WatchFace {

    protected var mAccent as Number;
    protected var mDateSetting as Number = FaceKit.DATE_NAMED;
    protected var mScale as Float = 1.0f;
    protected var mAwake as Boolean = true;
    protected var mEditMode as Boolean;
    protected var mData as FaceData = new FaceData();

    private var mDefaultAccent as Number;

    // The subclass calls loadSettings() at the end of its own initialize, once its
    // members exist.
    function initialize(editMode as Boolean, defaultAccent as Number) {
        WatchFace.initialize();
        mEditMode = editMode;
        mDefaultAccent = defaultAccent;
        mAccent = defaultAccent;
    }

    function onLayout(dc as Dc) as Void {
        mScale = dc.getWidth() / FaceKit.DESIGN;
        loadFonts();
    }

    // Load the face's fonts with FaceKit.loadFonts (never plain loadResource).
    function loadFonts() as Void {
    }

    function onExitSleep() as Void {
        mAwake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        mAwake = false;
        WatchUi.requestUpdate();
    }

    // Phone app settings first, then anything set in the watch face editor on top.
    function loadSettings() as Void {
        mAccent = FaceKit.prop("AccentColor", mDefaultAccent);
        mDateSetting = FaceKit.prop("DateFormat", FaceKit.DATE_NAMED);
        loadPhoneSettings();
        var editor = FaceEditor.settingsFor(null);
        if (editor != null) {
            applyEditor(editor);
        }
    }

    // The face's own properties from the Garmin Connect app.
    function loadPhoneSettings() as Void {
    }

    function applyEditor(settings as Application.WatchFaceConfig.Settings) as Void {
        var accent = settings.accentColor;
        if (accent != null && accent.color instanceof Number) {
            mAccent = accent.color as Number;
        }
    }

    // Draw the low-power screen: asleep (or forced in a demo build) on a watch that needs
    // burn-in protection, never inside the editor.
    function alwaysOn() as Boolean {
        return (!mAwake || FaceDemo.FORCE_AOD) && !mEditMode && FaceKit.burnInProtection();
    }

    // Always-On offset in design px for this minute; everything drawn in Always-On moves
    // by it, and stays FaceKit.AOD_SHIFT_MAX inside the rim.
    function aodShift(minute as Number) as Array<Number> {
        return FaceKit.aodShift(minute);
    }
}
