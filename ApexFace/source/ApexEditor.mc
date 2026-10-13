import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Garmin's native on-device watch face editor (Watch Face Configurations, API 5.1+).
// resources/configs/watchface.xml declares what can be edited: the data in slots
// 1-3 (fields) and 4 (arc), the accent colour and the data colour (numerals).
module ApexEditor {

    const SLOT_FIELD_1 = 1;
    const SLOT_ARC = 4;

    // Styles (configs/watchface.xml): the plain time, or with a colon
    const STYLE_PLAIN = 1;
    const STYLE_COLON = 2;
}

// Draws one editable slot through the view; the editor animates it while that slot is selected.
class ApexSlotDrawable extends WatchUi.Drawable {

    private var mView as ApexFaceView;
    private var mSlot as Number;

    function initialize(view as ApexFaceView, slot as Number, box as [Number, Number, Number, Number]) {
        Drawable.initialize({:locX => box[0], :locY => box[1], :width => box[2], :height => box[3]});
        mView = view;
        mSlot = slot;
    }

    function draw(dc as Dc) as Void {
        mView.drawSlot(dc, mSlot);
    }
}

// Input while the face runs inside the editor.
class ApexEditorDelegate extends WatchUi.WatchFaceDelegate {

    private var mView as ApexFaceView;

    function initialize(view as ApexFaceView) {
        WatchFaceDelegate.initialize();
        mView = view;
    }

    function onWatchFaceConfigEdited(options as {
            :configId as Application.WatchFaceConfig.Id,
            :type as WatchUi.WatchFaceConfigType or Null,
            :committed as Boolean }) as Void {
        mView.setEditConfig(options[:configId]);
        var settings = FaceEditor.settingsFor(options[:configId]);
        if (settings != null) {
            mView.applyEditor(settings, options[:type]);
        }
    }

    function getComplicationDrawable(complication as Application.WatchFaceConfig.ComplicationRef)
            as WatchUi.Drawable or WatchUi.ComplicationDrawableRef or Null {
        var slot = complication.uniqueIdentifier;
        if (slot == null) {
            return null;
        }
        var box = mView.slotBox(slot);
        if (box == null) {
            return null;
        }
        mView.setEditingSlot(slot);
        var bounds = new Graphics.BoundingBox();
        bounds.addRectangle(box[0], box[1], box[2], box[3]);
        return new WatchUi.ComplicationDrawableRef({
            :drawable => new ApexSlotDrawable(mView, slot, box),
            :boundingBox => bounds
        });
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var xy = clickEvent.getCoordinates();
        var slot = mView.slotAt(xy[0], xy[1]);
        if (slot != null) {
            setSelectedComplication(slot);
            return true;
        }
        return false;
    }
}
