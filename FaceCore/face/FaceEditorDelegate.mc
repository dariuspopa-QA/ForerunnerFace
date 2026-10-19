import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Passes on-watch editor changes and taps on the face (touch watches) to the face
// (FaceCoreApp adds it to every FaceCoreView face).
class FaceEditorDelegate extends WatchUi.WatchFaceDelegate {

    private var mView as FaceCoreView;

    function initialize(view as FaceCoreView) {
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
        }
        // Left the data page: the face draws every slot itself again.
        if (options[:type] != WatchUi.WATCH_FACE_CONFIG_TYPE_COMPLICATION) {
            mView.setEditingSlot(null);
        }
        WatchUi.requestUpdate();
    }

    // The editor's preview of the selected data slot (FaceSlots): the face draws that slot
    // alone, with the field the user just scrolled to.
    function getComplicationDrawable(complication as Application.WatchFaceConfig.ComplicationRef)
            as WatchUi.Drawable or WatchUi.ComplicationDrawableRef or Null {
        var slot = complication.uniqueIdentifier;
        if (slot == null) {
            return null;
        }
        mView.applyComplication(complication);
        var box = mView.slotBox(slot);
        if (box == null) {
            return null;
        }
        mView.setEditingSlot(slot);
        var bounds = new Graphics.BoundingBox();
        bounds.addRectangle(box[0], box[1], box[2], box[3]);
        return new WatchUi.ComplicationDrawableRef({
            :drawable => new FaceSlotDrawable(mView, slot, box),
            :boundingBox => bounds
        });
    }

    // In the editor, tapping a data slot selects it.
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (!mView.inEditor()) {
            return false;
        }
        var xy = clickEvent.getCoordinates();
        var slot = mView.slotAt(xy[0], xy[1]);
        if (slot != null) {
            setSelectedComplication(slot);
            return true;
        }
        return false;
    }

    // A tap on the running face (touch watches); the face decides what it hits.
    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var xy = clickEvent.getCoordinates();
        return mView.onFacePress(xy[0], xy[1]);
    }
}
