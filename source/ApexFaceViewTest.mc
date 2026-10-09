import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// View tests: the face is drawn into an offscreen bitmap the size of the watch the
// tests run on (positions are 454 px design values scaled by ApexTestUtil.px), and the
// layout it reports to the watch face editor (slot boxes, hit tests) is checked.

(:test)
function activeModeRendersFieldRowInsideTheScreen(logger as Logger) as Boolean {
    var view = new ApexFaceView(false);
    ApexTestUtil.render(view);
    var lastRight = -1;
    var first = null;
    var last = null;
    for (var slot = 1; slot <= 3; slot++) {
        var box = view.slotBox(slot);
        if (box == null) {
            continue;
        }
        Test.assertMessage(box[0] >= 0 && box[0] + box[2] <= ApexTestUtil.screen(), "field " + slot + " outside the screen");
        Test.assertMessage(box[1] < ApexTestUtil.px(290) && box[1] + box[3] > ApexTestUtil.px(316), "field " + slot + " box misses label / value rows");
        Test.assertMessage(box[0] > lastRight, "field " + slot + " overlaps the previous one");
        lastRight = box[0] + box[2];
        if (first == null) {
            first = box;
        }
        last = box;
    }
    if (first != null && last != null) {
        var centre = (first[0] + last[0] + last[2]) / 2.0f;
        ApexTestUtil.assertNear(centre, ApexTestUtil.screen() / 2.0f, 2, "field row centre");
    }
    return true;
}

(:test)
function arcSlotBoxIsTheRing(logger as Logger) as Boolean {
    var view = new ApexFaceView(true);
    ApexTestUtil.render(view);
    var box = view.slotBox(ApexEditor.SLOT_ARC);
    Test.assert(box != null);
    box = box as [Number, Number, Number, Number];
    // r = 198 + 4 around the centre
    ApexTestUtil.assertNear(box[0], ApexTestUtil.px(25), 1, "ring left");
    ApexTestUtil.assertNear(box[1], ApexTestUtil.px(25), 1, "ring top");
    ApexTestUtil.assertNear(box[2], ApexTestUtil.px(404), 1, "ring width");
    ApexTestUtil.assertNear(box[3], ApexTestUtil.px(404), 1, "ring height");
    return true;
}

(:test)
function slotBoxRejectsUnknownSlots(logger as Logger) as Boolean {
    var view = new ApexFaceView(true);
    ApexTestUtil.render(view);
    ApexTestUtil.assertEqual(view.slotBox(0), null);
    ApexTestUtil.assertEqual(view.slotBox(5), null);
    return true;
}

// In the editor every field slot is shown (empty ones as "--") so it can be tapped.
(:test)
function editModeShowsEveryFieldSlot(logger as Logger) as Boolean {
    var view = new ApexFaceView(true);
    ApexTestUtil.render(view);
    for (var slot = 1; slot <= 3; slot++) {
        Test.assertMessage(view.slotBox(slot) != null, "field slot " + slot + " hidden in the editor");
    }
    return true;
}

(:test)
function slotAtFindsEachSlotByItsBox(logger as Logger) as Boolean {
    var view = new ApexFaceView(true);
    ApexTestUtil.render(view);
    for (var slot = 1; slot <= 3; slot++) {
        var box = view.slotBox(slot) as [Number, Number, Number, Number];
        ApexTestUtil.assertEqual(view.slotAt(box[0] + box[2] / 2, box[1] + box[3] / 2), slot);
    }
    ApexTestUtil.assertEqual(view.slotAt(ApexTestUtil.px(227), ApexTestUtil.px(10)), ApexEditor.SLOT_ARC);      // rim at 12
    ApexTestUtil.assertEqual(view.slotAt(ApexTestUtil.px(227), ApexTestUtil.px(395)), ApexEditor.SLOT_ARC);     // readout
    ApexTestUtil.assertEqual(view.slotAt(ApexTestUtil.px(227), ApexTestUtil.px(185)), null);                   // time
    return true;
}

// Every display path draws without throwing.
(:test)
function everyDisplayModeRenders(logger as Logger) as Boolean {
    var view = new ApexFaceView(false);
    var dc = ApexTestUtil.render(view);
    view.onEnterSleep();
    view.onUpdate(dc);
    view.onExitSleep();
    view.onUpdate(dc);
    view.onShow();
    view.onHide();
    return true;
}

(:test)
function editorSlotsDrawOnTheirOwn(logger as Logger) as Boolean {
    var view = new ApexFaceView(true);
    var dc = ApexTestUtil.render(view);
    for (var slot = 1; slot <= ApexEditor.SLOT_ARC; slot++) {
        view.setEditingSlot(slot);
        view.onUpdate(dc);
        view.drawSlot(dc, slot);
    }
    view.setEditingSlot(null);
    view.onUpdate(dc);
    return true;
}

// Phone app settings. These tests load them with loadPhoneSettings, because a
// configuration in the on-device editor (which wins) would mask them.
(:test)
function emptyFieldSettingRecentresTheRow(logger as Logger) as Boolean {
    var saved = ApexTestUtil.saveProperties(["Field1", "Field2", "Field3"]);
    try {
        Application.Properties.setValue("Field1", ApexMetrics.F_HR);
        Application.Properties.setValue("Field2", ApexMetrics.F_EMPTY);
        Application.Properties.setValue("Field3", ApexMetrics.F_BATTERY);
        var view = new ApexFaceView(false);
        view.loadPhoneSettings();
        ApexTestUtil.render(view);
        var left = view.slotBox(1) as [Number, Number, Number, Number];
        var right = view.slotBox(3) as [Number, Number, Number, Number];
        ApexTestUtil.assertEqual(view.slotBox(2), null);
        ApexTestUtil.assertNear((left[0] + right[0] + right[2]) / 2.0f, ApexTestUtil.screen() / 2.0f, 2, "row centre");
    } finally {
        ApexTestUtil.restoreProperties(saved);
    }
    return true;
}

(:test)
function hiddenOrInvalidFieldSettingsAreEmpty(logger as Logger) as Boolean {
    var saved = ApexTestUtil.saveProperties(["Field1", "Field2", "Field3"]);
    try {
        Application.Properties.setValue("Field1", ApexMetrics.F_READY);
        Application.Properties.setValue("Field2", 42);
        Application.Properties.setValue("Field3", ApexMetrics.F_STEPS);
        var view = new ApexFaceView(false);
        view.loadPhoneSettings();
        ApexTestUtil.render(view);
        ApexTestUtil.assertEqual(view.slotBox(1), null);
        ApexTestUtil.assertEqual(view.slotBox(2), null);
        Test.assert(view.slotBox(3) != null);
    } finally {
        ApexTestUtil.restoreProperties(saved);
    }
    return true;
}

(:test)
function arcOffHidesTheArcSlotOutsideTheEditor(logger as Logger) as Boolean {
    var saved = ApexTestUtil.saveProperties(["Arc"]);
    try {
        Application.Properties.setValue("Arc", ApexMetrics.A_OFF);
        var face = new ApexFaceView(false);
        face.loadPhoneSettings();
        ApexTestUtil.render(face);
        ApexTestUtil.assertEqual(face.slotBox(ApexEditor.SLOT_ARC), null);
        ApexTestUtil.assertEqual(face.slotAt(ApexTestUtil.px(227), ApexTestUtil.px(10)), null);

        var editor = new ApexFaceView(true);
        editor.loadPhoneSettings();
        ApexTestUtil.render(editor);
        Test.assert(editor.slotBox(ApexEditor.SLOT_ARC) != null);
    } finally {
        ApexTestUtil.restoreProperties(saved);
    }
    return true;
}

// A changed setting takes effect when the settings are reloaded (onSettingsChanged).
(:test)
function reloadingSettingsPicksUpChangedProperties(logger as Logger) as Boolean {
    var saved = ApexTestUtil.saveProperties(["Arc"]);
    try {
        Application.Properties.setValue("Arc", ApexMetrics.A_BODY_BATTERY);
        var view = new ApexFaceView(false);
        view.loadPhoneSettings();
        var dc = ApexTestUtil.render(view);
        Test.assert(view.slotBox(ApexEditor.SLOT_ARC) != null);
        Application.Properties.setValue("Arc", ApexMetrics.A_OFF);
        view.loadPhoneSettings();
        view.onUpdate(dc);
        ApexTestUtil.assertEqual(view.slotBox(ApexEditor.SLOT_ARC), null);
    } finally {
        ApexTestUtil.restoreProperties(saved);
    }
    return true;
}

// MIP watches redraw the seconds in low power through onPartialUpdate; AMOLED
// watches ignore it. Either way it must be safe to call at any time.
(:test)
function partialUpdateIsSafeAwakeAndAsleep(logger as Logger) as Boolean {
    var view = new ApexFaceView(false);
    var dc = ApexTestUtil.render(view);
    view.onPartialUpdate(dc);
    view.onEnterSleep();
    view.onUpdate(dc);
    view.onPartialUpdate(dc);
    view.onPartialUpdate(dc);
    view.onExitSleep();
    view.onUpdate(dc);
    return true;
}

(:test)
function nightModeSettingsRender(logger as Logger) as Boolean {
    var saved = ApexTestUtil.saveProperties(["NightMode"]);
    try {
        for (var mode = 0; mode <= 3; mode++) {      // Off, Auto, On, and an invalid value
            Application.Properties.setValue("NightMode", mode);
            var view = new ApexFaceView(false);
            view.loadPhoneSettings();
            var dc = ApexTestUtil.render(view);
            view.onEnterSleep();
            view.onUpdate(dc);
        }
    } finally {
        ApexTestUtil.restoreProperties(saved);
    }
    return true;
}

// Colour and odd property values must not break loading or drawing.
(:test)
function colourSettingsIncludingAccentSentinelRender(logger as Logger) as Boolean {
    var saved = ApexTestUtil.saveProperties(["AccentColor", "NumeralColor", "InkColor", "DimColor"]);
    try {
        Application.Properties.setValue("AccentColor", 0xFF5A1F);
        Application.Properties.setValue("NumeralColor", ApexLayout.NUMERALS_ACCENT);
        Application.Properties.setValue("InkColor", 0xCFE3FF);
        Application.Properties.setValue("DimColor", 0x98A6B4);
        var view = new ApexFaceView(false);
        ApexTestUtil.render(view);
    } finally {
        ApexTestUtil.restoreProperties(saved);
    }
    return true;
}
