import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// FaceCore/slots: shared by the faces with tappable data slots (GoalBars, MinimalFace,
// PulseRings, TrainingPulse); their monkey.jungle adds ../FaceCore/slots.
//
// Support for Garmin's native on-device watch face editor ("Watch Face
// Configurations", API 5.1+; fr970 and newer - the fr265/265s have no
// editor and use the saved default settings). The editor lets the user
// pick a Style, the Data shown in each tappable slot, and an Accent Color;
// the view applies those choices as overrides on top of its saved settings.
//
// A view using this implements:
//   applyEditor(settings, editedType)  - apply a WatchFaceConfig.Settings
//   slotBox(slot) as [x, y, w, h]?      - screen box of an editable slot
//   slotAt(x, y) as Number?             - slot under a tap, if any
//   drawSlot(dc, slot)                  - draw one slot alone (editor preview)
//   setEditingSlot(slot)                - hide that slot while it's previewed

// Settings of the given configuration (null = the active one), or null when
// the device has no watch face editor.
function editorSettings(configId) {
    if (!(Application has :WatchFaceConfig)) {
        return null;
    }
    try {
        return Application.WatchFaceConfig.getSettings(configId);
    } catch (e) {
        return null;
    }
}

// [value, label] for any system data field the user picked in the editor
// (VO2 max, sleep score, recovery time...), or null if it has no value yet.
function complicationText(id) as Array or Null {
    if (id == null) {
        return null;
    }
    var c = null;
    try {
        c = Complications.getComplication(id);
    } catch (e) {
        return null;
    }
    if (c == null || c.value == null) {
        return null;
    }
    var v = c.value;
    var text;
    if (v instanceof Float) {
        text = (v == v.toNumber()) ? v.toNumber().format("%d") : v.format("%.1f");
    } else if (v instanceof Number || v instanceof Long) {
        text = v.format("%d");
    } else {
        text = v.toString();
    }
    if (c.unit instanceof String) {
        text = text + c.unit;
    }
    var label = (c.shortLabel != null) ? c.shortLabel : ((c.longLabel != null) ? c.longLabel : "");
    return [text, label.toUpper()];
}

function complicationType(id) as Number or Null {
    return (id == null) ? null : id.getType();
}

// Live updates for the system data fields shown on the face (nulls are
// skipped), replacing any earlier subscriptions.
function editorSubscribe(ids as Array, callback) as Void {
    try {
        Complications.unsubscribeFromAllUpdates();
        var any = false;
        for (var i = 0; i < ids.size(); i++) {
            if (ids[i] != null) {
                Complications.subscribeToUpdates(ids[i]);
                any = true;
            }
        }
        Complications.registerComplicationChangeCallback(any ? callback : null);
    } catch (e) {
        // Data fields just won't refresh live; the face still draws.
    }
}

// What the editor animates for the selected slot: draws that slot through the view.
class SlotDrawable extends WatchUi.Drawable {
    private var _view;
    private var _slot;

    function initialize(view, slot, box as Array) {
        Drawable.initialize({ :locX => box[0], :locY => box[1], :width => box[2], :height => box[3] });
        _view = view;
        _slot = slot;
    }

    function draw(dc as Graphics.Dc) as Void {
        _view.drawSlot(dc, _slot);
    }
}

// Delegate used only while the face runs inside the editor.
class EditorDelegate extends WatchUi.WatchFaceDelegate {
    private var _view;

    function initialize(view) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onWatchFaceConfigEdited(options) as Void {
        var id = options[:configId];
        if (id != null) {
            var s = editorSettings(id);
            if (s != null) {
                _view.applyEditor(s, options[:type]);
            }
        }
    }

    function getComplicationDrawable(ref) {
        var slot = ref.uniqueIdentifier;
        var box = _view.slotBox(slot);
        if (box == null) {
            return null;
        }
        _view.setEditingSlot(slot);
        var bb = new Graphics.BoundingBox();
        bb.addRectangle(box[0], box[1], box[2], box[3]);
        return new WatchUi.ComplicationDrawableRef({
            :drawable => new SlotDrawable(_view, slot, box),
            :boundingBox => bb
        });
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var xy = clickEvent.getCoordinates();
        var slot = _view.slotAt(xy[0], xy[1]);
        if (slot != null) {
            setSelectedComplication(slot);
            return true;
        }
        return false;
    }
}
