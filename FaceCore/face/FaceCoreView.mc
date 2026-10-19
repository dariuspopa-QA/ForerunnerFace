import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// What every face built on FaceCore shares: scale, sleep state, sensor data, settings
// (phone first, then the on-watch editor on top) and the Always-On decision. A face
// subclasses it as FaceView and only draws:
//
//   class FaceView extends FaceCoreView {
//       function initialize(editMode as Boolean) {
//           FaceCoreView.initialize(editMode, 0xFF6A13, FaceFormat.DATE_NAMED);   // default accent, date format
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
    protected var mDateSetting as Number = FaceFormat.DATE_NAMED;
    protected var mScale as Float = 1.0f;
    protected var mAwake as Boolean = true;
    protected var mEditMode as Boolean;
    protected var mData as FaceData = new FaceData();
    // AMOLED (burn-in protection, Always-On) or MIP (64 colours, the normal face stays on)
    protected var mAmoled as Boolean = true;

    // Fonts of the last loadFontSet that fell back to a system font (FaceDeviceTest: none
    // on any screen size)
    var fontFallbacks as Number = 0;

    // On-watch editor data slots (FaceSlots): the system data field picked per slot, and the
    // slot the editor is previewing (drawn by the editor, so the face leaves it out).
    protected var mSlotIds as Dictionary<Number, Complications.Id> = {} as Dictionary<Number, Complications.Id>;
    protected var mEditingSlot as Number or Null;

    private var mDefaultAccent as Number;
    private var mDefaultDate as Number;

    // The subclass calls loadSettings() at the end of its own initialize, once its
    // members exist.
    function initialize(editMode as Boolean, defaultAccent as Number, defaultDate as Number) {
        WatchFace.initialize();
        mEditMode = editMode;
        mDefaultAccent = defaultAccent;
        mDefaultDate = defaultDate;
        mAccent = defaultAccent;
        mDateSetting = defaultDate;
    }

    function onLayout(dc as Dc) as Void {
        mScale = dc.getWidth() / FaceKit.DESIGN;
        mAmoled = FaceKit.burnInProtection();
        loadFonts();
    }

    // Load the face's fonts with loadFontSet (never plain loadResource).
    function loadFonts() as Void {
    }

    // FaceKit.loadFonts, counting the fonts that fell back to a system font.
    function loadFontSet(ids as Array<ResourceId>, fallbacks as Array<FontType>) as Array<FontType> {
        var fonts = FaceKit.loadFonts(ids, fallbacks);
        fontFallbacks = 0;
        for (var i = 0; i < fonts.size(); i++) {
            if (fonts[i] instanceof Number) {
                fontFallbacks++;
            }
        }
        return fonts;
    }

    // The colour to draw on this screen. MIP screens show 64 colours (channels 00 / 55 /
    // AA / FF) and round each channel on its own, so a dark grey whose channels differ
    // slightly turns blue or brown (0x26282B -> 0x000055). Near-greys therefore go to one
    // neutral grey by brightness: below 0x1C black, then 0x555555, 0xAAAAAA from 0x80,
    // white from 0xD8. Every other colour, and everything on AMOLED, is left as it is.
    function ink(color as Number) as Number {
        if (mAmoled) {
            return color;
        }
        return FaceColor.mipGrey(color);
    }

    // The letter-spacing (px) to draw text with so it fits maxWidth px: as designed, or
    // none where it would not fit (small screens, where the text minimums make text
    // relatively wider than in the mockup).
    function fitTracking(dc as Dc, font as FontType, text as String, tracking as Float, maxWidth as Float) as Float {
        if (FaceKit.trackedWidth(dc, font, text, tracking) <= maxWidth) {
            return tracking;
        }
        return 0.0f;
    }

    // A tap on the running face at (x, y) px (touch watches). True if the face used it.
    function onFacePress(x as Number, y as Number) as Boolean {
        return false;
    }

    // Seconds (digits, hands, ticking rings) are drawn only while awake: asleep, a MIP
    // watch keeps the normal face but updates it once a minute (no partial updates here),
    // and an AMOLED watch shows the Always-On screen.
    function showSeconds() as Boolean {
        return mAwake;
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
        mDateSetting = FaceKit.prop("DateFormat", mDefaultDate);
        loadPhoneSettings();
        var editor = FaceEditor.settingsFor(null);
        if (editor != null) {
            applyEditor(editor);
        }
    }

    // New settings from the Garmin Connect app (FaceCoreApp.onSettingsChanged).
    function phoneSettingsChanged() as Void {
        loadSettings();
    }

    // The face's own properties from the Garmin Connect app.
    function loadPhoneSettings() as Void {
    }

    function applyEditor(settings as Application.WatchFaceConfig.Settings) as Void {
        var accent = settings.accentColor;
        if (accent != null && accent.color instanceof Number) {
            mAccent = accent.color as Number;
        }
        applySlots(settings);
    }

    // ---- Data slots (FaceSlots) ----
    // A face with slots lists them in resources/configs/watchface.xml (<complication id="N">)
    // and overrides slots(), slotBox() and drawSlot(); it draws slotText(slot) in each slot
    // except mEditingSlot. Faces whose applyEditor doesn't call FaceCoreView.applyEditor call
    // applySlots(settings) themselves.

    // The face's slot ids (none by default).
    function slots() as Array<Number> {
        return [] as Array<Number>;
    }

    // Screen box [x, y, w, h] of a slot, or null while it isn't shown.
    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        return null;
    }

    // Draws one slot alone (the editor's animated preview of it; the face's own drawing too).
    function drawSlot(dc as Dc, slot as Number) as Void {
    }

    // The slot under a tap, if any.
    function slotAt(x as Number, y as Number) as Number or Null {
        var ids = slots();
        for (var i = 0; i < ids.size(); i++) {
            if (FaceSlots.contains(slotBox(ids[i]), x, y)) {
                return ids[i];
            }
        }
        return null;
    }

    // The system data field picked for a slot, its type, and its [value, LABEL] (null without
    // a field or a value).
    function slotId(slot as Number) as Complications.Id or Null {
        return mSlotIds[slot];
    }

    function slotType(slot as Number) as Number or Null {
        var id = mSlotIds[slot];
        return id != null ? id.getType() : null;
    }

    function slotText(slot as Number) as [String, String] or Null {
        return FaceSlots.text(mSlotIds[slot]);
    }

    // Every slot's field from the editor, subscribed for live updates.
    function applySlots(settings as Application.WatchFaceConfig.Settings) as Void {
        var refs = settings.complicationSettings;
        if (refs == null || slots().size() == 0) {
            return;
        }
        for (var i = 0; i < refs.size(); i++) {
            applyComplication(refs[i]);
        }
        FaceSlots.subscribe(mSlotIds.values() as Array<Complications.Id or Null>, method(:onSlotChanged));
    }

    // One slot's field. The editor hands the slot it is about to preview to
    // getComplicationDrawable with the field the user just scrolled to, before it reports the
    // edit (onWatchFaceConfigEdited); applying it there keeps the preview current (ApexFace).
    function applyComplication(ref as Application.WatchFaceConfig.ComplicationRef) as Void {
        var slot = ref.uniqueIdentifier;
        if (slot == null) {
            return;
        }
        var id = ref.complicationId;
        if (id != null) {
            mSlotIds[slot] = id;
        } else {
            mSlotIds.remove(slot);
        }
    }

    function setEditingSlot(slot as Number or Null) as Void {
        mEditingSlot = slot;
        WatchUi.requestUpdate();
    }

    function onSlotChanged(id as Complications.Id) as Void {
        WatchUi.requestUpdate();
    }

    function inEditor() as Boolean {
        return mEditMode;
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
