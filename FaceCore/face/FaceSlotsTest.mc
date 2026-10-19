import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Core tests of the editor data slots (FaceSlots, FaceCoreView's slot hooks); they build into
// every FaceCoreView face's test run.
(:test)
module FaceSlotsTest {

    (:test)
    function boxContainsItsEdgesOnly(logger as Logger) as Boolean {
        var box = [10, 20, 50, 30] as [Number, Number, Number, Number];
        Test.assert(FaceSlots.contains(box, 10, 20));
        Test.assert(FaceSlots.contains(box, 60, 50));
        Test.assert(!FaceSlots.contains(box, 9, 20));
        Test.assert(!FaceSlots.contains(box, 61, 30));
        Test.assert(!FaceSlots.contains(box, 30, 51));
        Test.assert(!FaceSlots.contains(null, 0, 0));
        return true;
    }

    (:test)
    function tapFindsTheSlotUnderIt(logger as Logger) as Boolean {
        var view = new FaceSlotsTestView();
        Test.assertEqual(view.slotAt(30, 30), 1);
        Test.assertEqual(view.slotAt(120, 30), 2);
        Test.assert(view.slotAt(80, 30) == null);
        Test.assert(view.slotAt(30, 300) == null);
        return true;
    }

    // A face without slots: no slot under any tap, no field, nothing to draw.
    (:test)
    function faceWithoutSlotsHasNone(logger as Logger) as Boolean {
        var view = new FaceCoreView(true, 0xFFFFFF, FaceFormat.DATE_NAMED);
        Test.assertEqual(view.slots().size(), 0);
        Test.assert(view.slotAt(100, 100) == null);
        Test.assert(view.slotText(1) == null);
        Test.assert(view.slotType(1) == null);
        return true;
    }

    // A slot without a picked field shows nothing from the system, and setEditingSlot hides
    // and restores it.
    (:test)
    function emptySlotAndEditingSlot(logger as Logger) as Boolean {
        var view = new FaceSlotsTestView();
        Test.assert(view.slotId(1) == null);
        Test.assert(view.slotText(2) == null);
        view.setEditingSlot(2);
        Test.assertEqual(view.editing(), 2);
        view.setEditingSlot(null);
        Test.assert(view.editing() == null);
        return true;
    }

    // The face as running in the editor: draws with no picked fields, and the slot boxes
    // stay on screen.
    (:test)
    function realFaceSlotsOnScreen(logger as Logger) as Boolean {
        var view = new FaceView(true);
        var dc = FaceTestUtil.render(view);
        var ids = view.slots();
        for (var i = 0; i < ids.size(); i++) {
            var box = view.slotBox(ids[i]);
            if (box != null) {
                Test.assertMessage(box[0] >= 0 && box[1] >= 0 && box[0] + box[2] <= dc.getWidth()
                    && box[1] + box[3] <= dc.getHeight(), "slot " + ids[i] + " off screen");
                view.drawSlot(dc, ids[i]);
            }
        }
        logger.debug(ids.size() + " slots");
        return true;
    }
}

// Two slots side by side.
(:test)
class FaceSlotsTestView extends FaceCoreView {

    function initialize() {
        FaceCoreView.initialize(true, 0xFFFFFF, FaceFormat.DATE_NAMED);
    }

    function slots() as Array<Number> {
        return [1, 2] as Array<Number>;
    }

    function slotBox(slot as Number) as [Number, Number, Number, Number] or Null {
        if (slot == 1) {
            return [10, 10, 50, 30] as [Number, Number, Number, Number];
        }
        if (slot == 2) {
            return [100, 10, 50, 30] as [Number, Number, Number, Number];
        }
        return null;
    }

    function editing() as Number or Null {
        return mEditingSlot;
    }
}
