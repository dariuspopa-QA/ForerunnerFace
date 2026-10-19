import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Data slots (complications) of the on-watch editor for FaceCoreView faces: the user taps a
// slot in the editor and picks any system data field for it. FaceCoreView keeps the picked
// field per slot and FaceEditorDelegate does the editor side; a face only says where its
// slots are and draws them (FaceCoreView.slots / slotBox / drawSlot), and lists them in
// resources/configs/watchface.xml as <complication id="N">. (Faces with their own view use
// FaceCore/slots/EditorConfig.mc instead.)
module FaceSlots {

    // [value, LABEL] of the system data field picked for a slot ("52.4", "VO2 MAX"), or null
    // without a field or before it has a value.
    function text(id as Complications.Id or Null) as [String, String] or Null {
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
        var label = "";
        if (c.shortLabel != null) {
            label = (c.shortLabel as String).toUpper();
        } else if (c.longLabel != null) {
            label = (c.longLabel as String).toUpper();
        }
        return [FaceFormat.complicationValueText(c.value, c.unit), label];
    }

    // True if (x, y) lies inside box [x, y, w, h] (edges included); false for no box.
    function contains(box as [Number, Number, Number, Number] or Null, x as Number, y as Number) as Boolean {
        if (box == null) {
            return false;
        }
        return x >= box[0] && x <= box[0] + box[2] && y >= box[1] && y <= box[1] + box[3];
    }

    // Live updates for the picked fields (nulls skipped), replacing earlier subscriptions.
    function subscribe(ids as Array<Complications.Id or Null>, callback as Method(id as Complications.Id) as Void) as Void {
        try {
            Complications.unsubscribeFromAllUpdates();
            var any = false;
            for (var i = 0; i < ids.size(); i++) {
                var id = ids[i];
                if (id != null) {
                    Complications.subscribeToUpdates(id);
                    any = true;
                }
            }
            Complications.registerComplicationChangeCallback(any ? callback : null);
        } catch (e) {
            // The fields just won't refresh live; the face still draws them each minute.
        }
    }
}

// What the editor animates while a slot is selected: that slot alone, drawn by the face.
class FaceSlotDrawable extends WatchUi.Drawable {

    private var mView as FaceCoreView;
    private var mSlot as Number;

    function initialize(view as FaceCoreView, slot as Number, box as [Number, Number, Number, Number]) {
        Drawable.initialize({:locX => box[0], :locY => box[1], :width => box[2], :height => box[3]});
        mView = view;
        mSlot = slot;
    }

    function draw(dc as Graphics.Dc) as Void {
        mView.drawSlot(dc, mSlot);
    }
}
