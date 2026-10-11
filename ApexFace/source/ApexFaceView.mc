import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.WatchUi;

// APEX watch face. Geometry and colours follow CLAUDE.md; every coordinate is
// in design pixels (454 x 454) and multiplied by mScale when drawn.
class ApexFaceView extends WatchUi.WatchFace {

    // Design size and centre
    private const DESIGN = 454.0f;
    private const C = ApexLayout.C;

    // Tick ring (radii, pen widths)
    private const MINOR_R_IN = 216.0f;
    private const MINOR_R_OUT = 222.0f;
    private const MINOR_W = 1.4f;
    private const MAJOR_R_IN = 213.0f;
    private const MAJOR_R_OUT = 225.0f;
    private const MAJOR_W = 3.0f;

    // Arc: 270 degrees from bottom-left clockwise to bottom-right (CIQ degrees)
    private const ARC_R = 198.0f;
    private const ARC_W = 4.0f;
    private const ARC_START = ApexLayout.ARC_START;
    private const ARC_SWEEP = ApexLayout.ARC_SWEEP;

    // Date
    private const DATE_Y = 86.0f;
    private const DATE_SIZE = 22;
    private const DATE_TRACKING = 3.0f;

    // Time
    private const TIME_SIZE = 164;
    private const TIME_Y = 185.0f;
    private const HOURS_RIGHT_X = 222.0f;
    private const MINUTES_LEFT_X = 232.0f;

    // Separator and data fields
    private const SEP_HALF = 30.0f;
    private const SEP_Y = 266.0f;
    private const FIELD_GAP = 36.0f;
    private const FIELD_LABEL_Y = 290.0f;
    private const FIELD_LABEL_SIZE = 16;
    private const FIELD_VALUE_Y = 316.0f;
    private const FIELD_VALUE_SIZE = 28;
    private const LABEL_TRACKING = 2.0f;

    // Arc readout
    private const READOUT_VALUE_Y = ApexLayout.READOUT_VALUE_Y;
    private const READOUT_VALUE_SIZE = 26;
    private const READOUT_LABEL_Y = 412.0f;

    // Value row under the field labels and the arc readout value over its label, in
    // design pixels; computed in layoutRows from the real font heights
    private var mFieldValueY as Float = FIELD_VALUE_Y;
    private var mReadoutValueY as Float = READOUT_VALUE_Y;
    private const READOUT_LABEL_SIZE = 14;

    private const COLOR_GROUND = 0x000000;
    private var mAmoled as Boolean = true;

    // MIP watches keep the seconds in low power through onPartialUpdate (AMOLED
    // watches switch to Always-On instead). mLastSec: second last drawn, -1 = none.
    private var mPartialSeconds as Boolean = false;
    private var mLastSec as Number = -1;
    // Arc fill of the last full update, reused by partial updates
    private var mArcSweep as Float = 0.0f;

    // Seconds (Active mode only): trail on the rim, comet rotated to sec x 6 degrees
    private const TRAIL_R = 226.0f;
    private const TRAIL_WEIGHT = 0.55f;
    private const COMET_R_IN = 202.0f;
    private const COMET_R_OUT = 224.0f;
    private const COMET_W = 4.0f;

    // Day colours from settings / the watch face editor
    private var mDayAccent as Number = 0xC8FF2E;
    private var mDayNumerals as Number = 0xF4F4EF;
    private var mDayInk as Number = 0xF4F4EF;
    private var mDayDim as Number = 0xB0B0AA;

    // Night (red) mode: the NightMode setting, whether it is on now, and the
    // minute it (and the clock / date formats) was last evaluated
    private var mNightMode as Number = ApexLayout.NIGHT_OFF;
    private var mNight as Boolean = false;
    private var mNightMinute as Number = -1;

    // DateFormat setting (ApexFormat enum), the date format drawn, and whether the
    // watch shows 12 h time
    private var mDateSetting as Number = ApexFormat.DATE_WATCH;
    private var mDateFormat as Number = ApexFormat.DATE_DMY;
    private var mTwelveHour as Boolean = false;

    // Colours in use (ApexLayout.palette of the above)
    private var mAccent as Number = 0xC8FF2E;
    private var mNumerals as Number = 0xF4F4EF;
    private var mInk as Number = 0xF4F4EF;
    private var mDim as Number = 0xB0B0AA;
    private var mMinor as Number = ApexLayout.MINOR_AMOLED;
    private var mRule as Number = ApexLayout.RULE_AMOLED;
    private var mAodMajor as Number = ApexLayout.AOD_MAJOR;

    // Data from settings / the watch face editor. A field shows its built-in
    // metric unless the editor picked a system data field the face has no
    // own source for; that one is kept in mFieldComplications.
    private var mFieldIds as Array<Number> = [ApexMetrics.F_HR, ApexMetrics.F_STEPS, ApexMetrics.F_SUNSET];
    private var mFieldComplications as Array<Complications.Id or Null> = [null, null, null];
    private var mArcId as Number = ApexMetrics.A_BODY_BATTERY;

    private var mData as ApexData = new ApexData();
    private var mAwake as Boolean = true;

    // Burn-in offset in design pixels (non-zero only in Always-On)
    private var mShiftX as Float = 0.0f;
    private var mShiftY as Float = 0.0f;

    private var mScale as Float = 1.0f;
    private var mRing as BufferedBitmapReference or Null;
    private var mRingDirty as Boolean = true;

    // Custom bitmap fonts (Barlow Condensed / DM Mono, per screen size in
    // resources-round-*/fonts). System fonts stand in if they can't be loaded.
    private var mCustomFonts as Boolean = false;
    private var mFontHours as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontMinutes as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontTimeAod as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var mFontDate as FontType = Graphics.FONT_XTINY;
    private var mFontLabel as FontType = Graphics.FONT_XTINY;
    private var mFontValue as FontType = Graphics.FONT_SMALL;
    private var mFontReadoutValue as FontType = Graphics.FONT_SMALL;
    private var mFontReadoutLabel as FontType = Graphics.FONT_XTINY;

    // Field layout of the last update, used by the editor: per field slot the
    // [label, value] texts and the screen box [x, y, w, h] (null = not shown).
    private var mFieldTexts as Array<[String, String] or Null> = [null, null, null];
    private var mFieldBoxes as Array<[Number, Number, Number, Number] or Null> = [null, null, null];

    // Watch face editor: running inside it, and the slot it is currently animating
    private var mEditMode as Boolean;
    private var mEditingSlot as Number or Null;

    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        mEditMode = editMode;
        mAmoled = burnInProtection();
        mPartialSeconds = !mAmoled && !editMode;
        loadSettings();
    }

    function onLayout(dc as Dc) as Void {
        mScale = dc.getWidth() / DESIGN;
        loadFonts(dc);
        layoutRows(dc);
        mRingDirty = true;
    }

    // Rows keep their design positions unless the fonts are taller than designed
    // (minimum sizes on small screens, system font stand-ins): field values move
    // down, the arc readout value moves up so its label stays clear of the rim.
    private function layoutRows(dc as Dc) as Void {
        mFieldValueY = ApexLayout.rowBelow(FIELD_LABEL_Y * mScale, FIELD_VALUE_Y * mScale,
            rowExtent(dc, mFontLabel), rowExtent(dc, mFontValue)) / mScale;
        mReadoutValueY = ApexLayout.rowAbove(READOUT_LABEL_Y * mScale, READOUT_VALUE_Y * mScale,
            rowExtent(dc, mFontReadoutLabel), rowExtent(dc, mFontReadoutValue)) / mScale;
    }

    // Half the height a text row needs, in px. Custom fonts report their cap height
    // (line box cropped to the ink), system fonts a line height with leading.
    private function rowExtent(dc as Dc, font as FontType) as Float {
        var h = dc.getFontHeight(font);
        return ApexLayout.rowExtent(h, mCustomFonts, mScale);
    }

    function onUpdate(dc as Dc) as Void {
        dc.setAntiAlias(true);
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        updateNight(clock);

        if (!mAwake && !mEditMode && burnInProtection()) {
            drawAlwaysOn(dc, clock, now);
            return;
        }
        mShiftX = 0.0f;
        mShiftY = 0.0f;

        if (mRingDirty) {
            buildRing(dc.getWidth(), dc.getHeight());
        }

        // The ring bitmap includes the black ground, so it replaces dc.clear()
        var ring = ringBitmap();
        if (ring != null) {
            dc.drawBitmap(0, 0, ring);
        } else {
            dc.setColor(COLOR_GROUND, COLOR_GROUND);
            dc.clear();
            drawStaticRing(dc);
        }

        mData.refresh(clock);

        if (mAwake || mPartialSeconds) {
            drawSeconds(dc, clock.sec);
        }
        if (arcVisible() && mEditingSlot != ApexEditor.SLOT_ARC) {
            drawArcSlot(dc);
        }
        drawDate(dc, now);
        drawTime(dc, now, mFontHours, mFontMinutes, mNumerals, mNumerals);
        drawFields(dc, clock);
    }

    function onShow() as Void {
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        mAwake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        mAwake = false;
        WatchUi.requestUpdate();
    }

    private function burnInProtection() as Boolean {
        var settings = System.getDeviceSettings();
        return (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
    }

    // ---- Always-On -----------------------------------------------------

    // Only the date, a thin time (minutes dim) and the 12 major ticks, shifted
    // each minute. Nothing accent-coloured, no seconds, arc or fields.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime, now as Gregorian.Info) as Void {
        // Everything moves with ApexLayout.AOD_TIME_SHIFTS; the ticks are inset by the
        // largest shift so they stay on the round screen.
        var shift = ApexLayout.aodTimeShift(clock.min);
        mShiftX = shift[0].toFloat();
        mShiftY = shift[1].toFloat();

        dc.setColor(COLOR_GROUND, COLOR_GROUND);
        dc.clear();
        dc.setPenWidth(ApexLayout.penWidth(MAJOR_W, mScale, mAmoled));
        dc.setColor(mAodMajor, Graphics.COLOR_TRANSPARENT);
        var inset = ApexLayout.AOD_SHIFT_MAX;
        for (var i = 0; i < 60; i += 5) {
            drawRadial(dc, i * 6, MAJOR_R_IN - inset, MAJOR_R_OUT - inset);
        }
        dc.setPenWidth(1);

        drawDate(dc, now);
        drawTime(dc, now, mFontTimeAod, mFontMinutes, mNumerals, mDim);
    }

    // ---- Seconds -------------------------------------------------------

    // MIP watches in low power: called once a second between the minute updates.
    // Only the box around the previous and the new comet is redrawn (ring background,
    // arc fill, trail, comet), which keeps the update inside the power budget.
    function onPartialUpdate(dc as Dc) as Void {
        var ring = ringBitmap();
        if (!mPartialSeconds || ring == null || mLastSec < 0) {
            return;
        }
        var sec = System.getClockTime().sec;
        if (sec == mLastSec) {
            return;
        }
        var box = ApexLayout.unionBox(ApexLayout.cometBox(mLastSec, mScale), ApexLayout.cometBox(sec, mScale));
        dc.setClip(box[0], box[1], box[2], box[3]);
        dc.drawBitmap(0, 0, ring);
        drawArcFill(dc);
        drawSeconds(dc, sec);
        dc.clearClip();
    }

    private function drawSeconds(dc as Dc, sec as Number) as Void {
        mLastSec = sec;
        var centre = C * mScale;
        if (sec > 0) {
            dc.setColor(ApexLayout.blend(mAccent, TRAIL_WEIGHT), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(ApexLayout.penWidth(1.0f, mScale, mAmoled));
            dc.drawArc(centre, centre, TRAIL_R * mScale, Graphics.ARC_CLOCKWISE, 90, ApexLayout.trailEnd(sec));
        }

        var pIn = ApexLayout.clockPoint(sec * 6, COMET_R_IN);
        var pOut = ApexLayout.clockPoint(sec * 6, COMET_R_OUT);
        var x1 = (C + pIn[0]) * mScale;
        var y1 = (C + pIn[1]) * mScale;
        var x2 = (C + pOut[0]) * mScale;
        var y2 = (C + pOut[1]) * mScale;
        var capR = COMET_W * mScale / 2;
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(ApexLayout.penWidth(COMET_W, mScale, mAmoled));
        dc.drawLine(x1, y1, x2, y2);
        dc.fillCircle(x1, y1, capR);
        dc.fillCircle(x2, y2, capR);
        dc.setPenWidth(1);
    }

    // ---- Settings ------------------------------------------------------

    // Phone app settings first, then anything set in the watch face editor on top.
    function loadSettings() as Void {
        loadPhoneSettings();
        var editor = ApexEditor.activeSettings();
        if (editor != null) {
            applyEditor(editor, null);
        }
    }

    // Settings from the Garmin Connect app only.
    function loadPhoneSettings() as Void {
        mDayAccent = prop("AccentColor", 0xC8FF2E);
        var numerals = prop("NumeralColor", 0xF4F4EF);
        mDayNumerals = ApexLayout.numeralColor(numerals, mDayAccent);
        mDayInk = prop("InkColor", 0xF4F4EF);
        mDayDim = prop("DimColor", 0xB0B0AA);
        mDateSetting = prop("DateFormat", ApexFormat.DATE_WATCH);
        updateFormats();
        var night = prop("NightMode", ApexLayout.NIGHT_OFF);
        mNightMode = (night >= ApexLayout.NIGHT_OFF && night <= ApexLayout.NIGHT_ON) ? night : ApexLayout.NIGHT_OFF;
        mNightMinute = -1;
        mNight = nightNow(System.getClockTime());
        mFieldIds = [
            ApexMetrics.validField(prop("Field1", ApexMetrics.F_HR)),
            ApexMetrics.validField(prop("Field2", ApexMetrics.F_STEPS)),
            ApexMetrics.validField(prop("Field3", ApexMetrics.F_SUNSET))
        ];
        mFieldComplications = [null, null, null];
        mArcId = ApexMetrics.validArc(prop("Arc", ApexMetrics.A_BODY_BATTERY));
        applyPalette();
    }

    // ---- Night mode ----------------------------------------------------

    // Re-evaluates Auto night mode once a minute and switches the palette on change;
    // also picks up a change of the watch's 12 / 24 h or unit settings.
    private function updateNight(clock as System.ClockTime) as Void {
        var minute = clock.hour * 60 + clock.min;
        if (minute == mNightMinute) {
            return;
        }
        mNightMinute = minute;
        updateFormats();
        var night = nightNow(clock);
        if (night != mNight) {
            mNight = night;
            applyPalette();
        }
    }

    // 12 / 24 h time from the watch's own setting; the date format from the DateFormat
    // setting (or the watch's distance units, see ApexFormat.dateFormat).
    private function updateFormats() as Void {
        var settings = System.getDeviceSettings();
        mTwelveHour = !settings.is24Hour;
        mData.setTwelveHour(mTwelveHour);
        mDateFormat = ApexFormat.dateFormat(mDateSetting, settings.distanceUnits == System.UNIT_STATUTE);
    }

    // On: always. Auto: between the sleep and wake times of the user profile.
    private function nightNow(clock as System.ClockTime) as Boolean {
        if (mNightMode == ApexLayout.NIGHT_ON) {
            return true;
        }
        if (mNightMode != ApexLayout.NIGHT_AUTO) {
            return false;
        }
        var profile = UserProfile.getProfile();
        var sleep = profile.sleepTime;
        var wake = profile.wakeTime;
        if (sleep == null || wake == null) {
            return false;
        }
        return ApexLayout.inSleepWindow(clock.hour * 60 + clock.min,
            (sleep as Time.Duration).value() / 60 % 1440, (wake as Time.Duration).value() / 60 % 1440);
    }

    private function applyPalette() as Void {
        var p = ApexLayout.palette([mDayAccent, mDayNumerals, mDayInk, mDayDim], mAmoled, mNight);
        mAccent = p[ApexLayout.P_ACCENT];
        mNumerals = p[ApexLayout.P_NUMERALS];
        mInk = p[ApexLayout.P_INK];
        mDim = p[ApexLayout.P_DIM];
        mMinor = p[ApexLayout.P_MINOR];
        mRule = p[ApexLayout.P_RULE];
        mAodMajor = p[ApexLayout.P_AOD_MAJOR];
        mRingDirty = true;
    }

    private function prop(key as String, fallback as Number) as Number {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
        } catch (e) {
            value = null;
        }
        return (value instanceof Number) ? value : fallback;
    }

    // ---- Watch face editor ---------------------------------------------

    function applyEditor(settings as Application.WatchFaceConfig.Settings, editedType as WatchUi.WatchFaceConfigType or Null) as Void {
        var accent = settings.accentColor;
        if (accent != null && accent.color instanceof Number) {
            mDayAccent = accent.color as Number;
        }
        var dataColor = settings.complicationColor;
        if (dataColor != null && dataColor.color instanceof Number) {
            mDayNumerals = dataColor.color as Number;
        }

        var refs = settings.complicationSettings;
        if (refs != null) {
            for (var i = 0; i < refs.size(); i++) {
                var slot = refs[i].uniqueIdentifier;
                var id = refs[i].complicationId;
                if (slot == null || id == null) {
                    continue;
                }
                var type = id.getType();
                if (slot == ApexEditor.SLOT_ARC) {
                    var arc = ApexMetrics.arcForComplication(type);
                    if (arc != null) {
                        mArcId = arc;
                    }
                } else if (slot >= ApexEditor.SLOT_FIELD_1 && slot < ApexEditor.SLOT_FIELD_1 + 3) {
                    var index = slot - ApexEditor.SLOT_FIELD_1;
                    var field = ApexMetrics.fieldForComplication(type);
                    if (field != null) {
                        mFieldIds[index] = field;
                        mFieldComplications[index] = null;
                    } else {
                        mFieldComplications[index] = id;
                    }
                }
            }
        }

        if (editedType != WatchUi.WATCH_FACE_CONFIG_TYPE_COMPLICATION) {
            mEditingSlot = null;
        }
        applyPalette();
        WatchUi.requestUpdate();
    }

    // The editor draws this slot itself (animated), so the face leaves it out.
    function setEditingSlot(slot as Number or Null) as Void {
        mEditingSlot = slot;
        WatchUi.requestUpdate();
    }

    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        if (slot == ApexEditor.SLOT_ARC) {
            if (!arcVisible()) {
                return null;
            }
            var r = ARC_R + ARC_W;
            return [px(C - r), px(C - r), px(2 * r), px(2 * r)];
        }
        var index = slot - ApexEditor.SLOT_FIELD_1;
        return (index >= 0 && index < 3) ? mFieldBoxes[index] : null;
    }

    // Fields first; the rim and the readout below the fields count as the arc.
    function slotAt(x as Number, y as Number) as Number or Null {
        for (var i = 0; i < 3; i++) {
            if (ApexLayout.boxContains(mFieldBoxes[i], x, y)) {
                return ApexEditor.SLOT_FIELD_1 + i;
            }
        }
        if (!arcVisible()) {
            return null;
        }
        if (ApexLayout.inArcZone(x / mScale - C, y / mScale - C)) {
            return ApexEditor.SLOT_ARC;
        }
        return null;
    }

    function drawSlot(dc as Dc, slot as Number) as Void {
        dc.setAntiAlias(true);
        if (slot == ApexEditor.SLOT_ARC) {
            drawArcSlot(dc);
        } else {
            var index = slot - ApexEditor.SLOT_FIELD_1;
            if (index >= 0 && index < 3) {
                drawField(dc, index);
            }
        }
    }

    // ---- Setup ---------------------------------------------------------

    private function loadFonts(dc as Dc) as Void {
        try {
            var fonts = [Rez.Fonts.TimeHeavy, Rez.Fonts.TimeThin, Rez.Fonts.TimeAod, Rez.Fonts.Mono22,
                Rez.Fonts.Mono16, Rez.Fonts.Value, Rez.Fonts.ArcValue, Rez.Fonts.Mono14] as Array<ResourceId>;
            var loaded = [] as Array<FontType>;
            for (var i = 0; i < fonts.size(); i++) {
                var font = strongResource(fonts[i]);
                if (font == null) {
                    break;
                }
                loaded.add(font as FontResource);
            }
            if (loaded.size() == fonts.size()) {
                mFontHours = loaded[0];
                mFontMinutes = loaded[1];
                mFontTimeAod = loaded[2];
                mFontDate = loaded[3];
                mFontLabel = loaded[4];
                mFontValue = loaded[5];
                mFontReadoutValue = loaded[6];
                mFontReadoutLabel = loaded[7];
                mCustomFonts = true;
                return;
            }
        } catch (e) {
        }
        mCustomFonts = false;
        loadSystemFonts(dc);
    }

    // On Connect IQ 4+ loadResource returns fonts as references into the shared
    // graphics pool, and the watch may purge the resource behind a reference while
    // the face holds nothing stronger. Drawing with a reference it then can't bring
    // back is a fatal Invalid Value that try/catch can't stop (fr970 crash log,
    // 11 Oct 2026: measuring the arc label). So the face keeps the resource itself.
    private function strongResource(id as ResourceId) as Object or Null {
        var resource = WatchUi.loadResource(id);
        if (resource instanceof Graphics.ResourceReference) {
            return resource.get();
        }
        return resource;
    }

    private function loadSystemFonts(dc as Dc) as Void {
        var numbers = [Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_THAI_HOT] as Array<FontType>;
        var texts = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL,
            Graphics.FONT_MEDIUM, Graphics.FONT_LARGE] as Array<FontType>;
        mFontHours = vectorFont(dc, "RobotoCondensedBold", TIME_SIZE, numbers);
        mFontMinutes = vectorFont(dc, "RobotoCondensedRegular", TIME_SIZE, numbers);
        // Always-On hours are thin (spec: weight 300); the lightest system stand-in
        // is the minutes' face, so share that font object.
        mFontTimeAod = mFontMinutes;
        mFontDate = vectorFont(dc, "RobotoRegular", DATE_SIZE, texts);
        mFontLabel = vectorFont(dc, "RobotoRegular", FIELD_LABEL_SIZE, texts);
        mFontValue = vectorFont(dc, "RobotoCondensedBold", FIELD_VALUE_SIZE, texts);
        mFontReadoutValue = vectorFont(dc, "RobotoCondensedBold", READOUT_VALUE_SIZE, texts);
        mFontReadoutLabel = vectorFont(dc, "RobotoRegular", READOUT_LABEL_SIZE, texts);
    }

    // Scalable system font; where there are none (MIP watches) the fixed system
    // font closest to the design size on this screen.
    private function vectorFont(dc as Dc, face as String, size as Number, fallbacks as Array<FontType>) as FontType {
        if (Graphics has :getVectorFont) {
            var font = Graphics.getVectorFont({:face => face, :size => px(size)});
            if (font != null) {
                return font;
            }
        }
        var heights = new Array<Number>[fallbacks.size()];
        for (var i = 0; i < fallbacks.size(); i++) {
            heights[i] = dc.getFontHeight(fallbacks[i]);
        }
        return fallbacks[ApexLayout.pickFont(heights, size * mScale)];
    }

    // Draw the ground, tick ring and arc track once into a buffered bitmap. If
    // graphics memory is short, mRing stays null and onUpdate draws them directly.
    private function buildRing(width as Number, height as Number) as Void {
        mRingDirty = false;
        mRing = null;
        var ring;
        var bitmap;
        try {
            ring = Graphics.createBufferedBitmap({:width => width, :height => height});
            // get() allocates from the pool and throws when it is full
            bitmap = ring.get();
        } catch (e) {
            return;
        }
        if (bitmap == null) {
            return;
        }
        var bdc = (bitmap as BufferedBitmap).getDc();
        bdc.setAntiAlias(true);
        bdc.setColor(COLOR_GROUND, COLOR_GROUND);
        bdc.clear();
        drawStaticRing(bdc);
        mRing = ring;
    }

    // The ring is drawn from the bitmap get() returns, never from the pool reference
    // itself (see strongResource); if the pool can't give it back, onUpdate draws
    // the ring directly.
    private function ringBitmap() as BufferedBitmap or Null {
        var ring = mRing;
        if (ring == null) {
            return null;
        }
        try {
            return ring.get() as BufferedBitmap or Null;
        } catch (e) {
            return null;
        }
    }

    // ---- Drawing -------------------------------------------------------

    private function drawStaticRing(dc as Dc) as Void {
        dc.setPenWidth(ApexLayout.penWidth(MINOR_W, mScale, mAmoled));
        dc.setColor(mMinor, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i++) {
            if (i % 5 != 0) {
                drawRadial(dc, i * 6, MINOR_R_IN, MINOR_R_OUT);
            }
        }

        dc.setPenWidth(ApexLayout.penWidth(MAJOR_W, mScale, mAmoled));
        dc.setColor(mDim, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i += 5) {
            drawRadial(dc, i * 6, MAJOR_R_IN, MAJOR_R_OUT);
        }

        if (arcVisible()) {
            dc.setPenWidth(ApexLayout.penWidth(ARC_W, mScale, mAmoled));
            dc.setColor(mRule, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(C * mScale, C * mScale, ARC_R * mScale, Graphics.ARC_CLOCKWISE,
                ARC_START, ARC_START - ARC_SWEEP);
        }
        dc.setPenWidth(1);
    }

    // Line along a clock angle (0 = 12 o'clock, clockwise) between two radii.
    private function drawRadial(dc as Dc, clockDeg as Numeric, rIn as Float, rOut as Float) as Void {
        var pIn = ApexLayout.clockPoint(clockDeg, rIn);
        var pOut = ApexLayout.clockPoint(clockDeg, rOut);
        dc.drawLine(
            (C + mShiftX + pIn[0]) * mScale, (C + mShiftY + pIn[1]) * mScale,
            (C + mShiftX + pOut[0]) * mScale, (C + mShiftY + pOut[1]) * mScale);
    }

    private function drawDate(dc as Dc, now as Gregorian.Info) as Void {
        var text = ApexFormat.dateText(now.day_of_week as Number, now.day as Number, now.month as Number,
            now.year as Number, mDateFormat);
        drawTracked(dc, text, C, DATE_Y, mFontDate, DATE_TRACKING, mDim);
    }

    private function drawTime(dc as Dc, now as Gregorian.Info, hoursFont as FontType, minutesFont as FontType,
            hoursColor as Number, minutesColor as Number) as Void {
        var y = (TIME_Y + mShiftY) * mScale;
        dc.setColor(hoursColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText((HOURS_RIGHT_X + mShiftX) * mScale, y, hoursFont, ApexFormat.hourText(now.hour as Number, mTwelveHour),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(minutesColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText((MINUTES_LEFT_X + mShiftX) * mScale, y, minutesFont, ApexFormat.twoDigits(now.min as Number),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Up to three columns centred on the screen; empty slots are skipped and the
    // row re-centres. In the editor, empty slots show "--" so they can be tapped.
    private function drawFields(dc as Dc, clock as System.ClockTime) as Void {
        var widths = [null, null, null] as Array<Float or Null>;
        var count = 0;
        for (var i = 0; i < 3; i++) {
            mFieldBoxes[i] = null;
            mFieldTexts[i] = fieldTexts(i, clock);
            var texts = mFieldTexts[i];
            if (texts == null) {
                continue;
            }
            var labelW = trackedWidth(dc, texts[0], mFontLabel, LABEL_TRACKING);
            var valueW = dc.getTextWidthInPixels(texts[1], mFontValue).toFloat();
            widths[i] = labelW > valueW ? labelW : valueW;
            count++;
        }
        if (count == 0) {
            return;
        }
        var lefts = ApexLayout.fieldColumns(widths, FIELD_GAP * mScale, C * mScale);

        dc.setPenWidth(1);
        dc.setColor(mRule, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((C - SEP_HALF) * mScale, SEP_Y * mScale, (C + SEP_HALF) * mScale, SEP_Y * mScale);

        var top = px(FIELD_LABEL_Y - 12);
        var height = px(mFieldValueY + 18) - top;
        for (var i = 0; i < 3; i++) {
            var left = lefts[i];
            if (left == null) {
                continue;
            }
            mFieldBoxes[i] = [left.toNumber(), top, Math.ceil(widths[i] as Float).toNumber(), height];
            if (mEditingSlot != ApexEditor.SLOT_FIELD_1 + i) {
                drawField(dc, i);
            }
        }
    }

    // [label, value] for a field slot, or null when the slot is empty.
    private function fieldTexts(index as Number, clock as System.ClockTime) as [String, String] or Null {
        var complication = mFieldComplications[index];
        if (complication != null) {
            var ct = ApexMetrics.complicationText(complication);
            return [ct[1], ct[0]];
        }
        var id = mFieldIds[index];
        if (id == ApexMetrics.F_EMPTY) {
            return mEditMode ? ["", ApexMetrics.NO_VALUE] : null;
        }
        return [ApexMetrics.fieldLabel(id), mData.fieldValue(id, clock, mAwake)];
    }

    private function drawField(dc as Dc, index as Number) as Void {
        var box = mFieldBoxes[index];
        var texts = mFieldTexts[index];
        if (box == null || texts == null) {
            return;
        }
        var cx = (box[0] + box[2] / 2.0f) / mScale;
        drawTracked(dc, texts[0], cx, FIELD_LABEL_Y, mFontLabel, LABEL_TRACKING, mDim);
        dc.setColor(mInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx * mScale, mFieldValueY * mScale, mFontValue, texts[1],
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function arcVisible() as Boolean {
        return mArcId != ApexMetrics.A_OFF || mEditMode;
    }

    // Arc fill (from the bottom-left end, round caps) and the readout in the gap at 6 o'clock.
    private function drawArcSlot(dc as Dc) as Void {
        if (mArcId == ApexMetrics.A_OFF) {
            return;
        }
        mArcSweep = ApexLayout.arcSweep(mData.arcFraction(mArcId));
        drawArcFill(dc);

        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(C * mScale, mReadoutValueY * mScale, mFontReadoutValue, mData.arcReadout(mArcId),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawTracked(dc, ApexMetrics.arcLabel(mArcId), C, READOUT_LABEL_Y, mFontReadoutLabel, LABEL_TRACKING, mDim);
    }

    // The accent part of the arc, mArcSweep degrees from the bottom-left end.
    private function drawArcFill(dc as Dc) as Void {
        if (mArcId == ApexMetrics.A_OFF || mArcSweep < 1.0f) {
            return;
        }
        var cx = C * mScale;
        var r = ARC_R * mScale;
        var end = ARC_START - mArcSweep;
        dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(ApexLayout.penWidth(ARC_W, mScale, mAmoled));
        dc.drawArc(cx, cx, r, Graphics.ARC_CLOCKWISE, ARC_START, end);
        dc.setPenWidth(1);
        var capR = ARC_W * mScale / 2;
        fillCap(dc, cx, r, ARC_START, capR);
        fillCap(dc, cx, r, end, capR);
    }

    // Round cap at a CIQ angle (0 = 3 o'clock, counter-clockwise) on the arc.
    private function fillCap(dc as Dc, centre as Float, r as Float, ciqDeg as Numeric, capR as Float) as Void {
        var p = ApexLayout.ciqPoint(ciqDeg, r);
        dc.fillCircle(centre + p[0], centre + p[1], capR);
    }

    // drawText has no letter-spacing, so tracked labels are drawn glyph by glyph,
    // centred on design x = cx.
    private function drawTracked(dc as Dc, text as String, cx as Float, y as Float,
            font as FontType, tracking as Float, color as Number) as Void {
        if (text.length() == 0) {
            return;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var chars = text.toCharArray();
        var step = tracking * mScale;
        var x = (cx + mShiftX) * mScale - trackedWidth(dc, text, font, tracking) / 2;
        var yy = (y + mShiftY) * mScale;
        for (var i = 0; i < chars.size(); i++) {
            var ch = chars[i].toString();
            dc.drawText(x, yy, font, ch, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(ch, font) + step;
        }
    }

    private function trackedWidth(dc as Dc, text as String, font as FontType, tracking as Float) as Float {
        var chars = text.toCharArray();
        if (chars.size() == 0) {
            return 0.0f;
        }
        var width = tracking * mScale * (chars.size() - 1);
        for (var i = 0; i < chars.size(); i++) {
            width += dc.getTextWidthInPixels(chars[i].toString(), font);
        }
        return width;
    }

    private function px(size as Numeric) as Number {
        return Math.round(size * mScale).toNumber();
    }

    // Computed layout and state for the per-watch tests (debug builds only; release
    // builds, as exported for the store, leave it out). Positions are row centres in
    // px, heights are the fonts' line heights in px.
    (:debug)
    function testProbe(dc as Dc) as Dictionary<Symbol, Numeric or Boolean> {
        return {
            :scale => mScale, :customFonts => mCustomFonts, :amoled => mAmoled,
            :fontsHeld => !((mFontHours as Object) instanceof Graphics.ResourceReference)
                && !((mFontReadoutLabel as Object) instanceof Graphics.ResourceReference),
            :partialSeconds => mPartialSeconds, :night => mNight,
            :minor => mMinor, :rule => mRule, :accent => mAccent,
            :dateY => DATE_Y * mScale, :timeY => TIME_Y * mScale, :sepY => SEP_Y * mScale,
            :labelY => FIELD_LABEL_Y * mScale, :valueY => mFieldValueY * mScale,
            :readoutValueY => mReadoutValueY * mScale, :readoutLabelY => READOUT_LABEL_Y * mScale,
            :hoursRight => HOURS_RIGHT_X * mScale, :minutesLeft => MINUTES_LEFT_X * mScale,
            :arcInner => (ARC_R - ARC_W) * mScale,
            :hDate => dc.getFontHeight(mFontDate), :hHours => dc.getFontHeight(mFontHours),
            :hLabel => dc.getFontHeight(mFontLabel), :hValue => dc.getFontHeight(mFontValue),
            :hReadoutValue => dc.getFontHeight(mFontReadoutValue),
            :hReadoutLabel => dc.getFontHeight(mFontReadoutLabel),
            :wHours => dc.getTextWidthInPixels("00", mFontHours),
            :wMinutes => dc.getTextWidthInPixels("00", mFontMinutes),
            :wHoursAod => dc.getTextWidthInPixels("00", mFontTimeAod)
        };
    }
}
