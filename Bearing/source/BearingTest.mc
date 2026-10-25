import Toybox.Complications;
import Toybox.Lang;
import Toybox.Test;

// Bearing's own tests: what this face customizes, i.e. its drawing in every display mode,
// every accent colour and its two data slots. The shared core is tested in FaceCore/test.
(:test)
module BearingTest {

    (:test)
    function drawsEveryMode(logger as Logger) as Boolean {
        FaceTestUtil.renderEveryMode(new FaceView(false));
        // Inside the on-watch editor (never Always-On there)
        FaceTestUtil.renderEveryMode(new FaceView(true));
        return true;
    }

    (:test)
    function drawsEverySettingValue(logger as Logger) as Boolean {
        var view = new FaceView(false);
        FaceTestUtil.eachSettingValue(view, {
            "AccentColor" => [0xA8D3F3, 0x9EE6C9, 0xF5C27A, 0xF2A7BD]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    // Both slots sit on screen, apart, and a tap on each selects it.
    (:test)
    function slotsOnScreen(logger as Logger) as Boolean {
        var view = new BearingTestView();
        var dc = FaceTestUtil.render(view);
        var top = view.slotBox(1) as [Number, Number, Number, Number];
        var bottom = view.slotBox(2) as [Number, Number, Number, Number];
        Test.assert(top[1] + top[3] < bottom[1]);
        Test.assertEqual(view.slotAt(dc.getWidth() / 2, top[1] + top[3] / 2), 1);
        Test.assertEqual(view.slotAt(dc.getWidth() / 2, bottom[1] + bottom[3] / 2), 2);
        Test.assert(view.slotBox(3) == null);
        return true;
    }

    // Battery above and steps below without a pick; a picked field replaces either.
    (:test)
    function slotFields(logger as Logger) as Boolean {
        var view = new BearingTestView();
        Test.assertEqual(view.shownType(1), Complications.COMPLICATION_TYPE_BATTERY);
        Test.assertEqual(view.shownType(2), Complications.COMPLICATION_TYPE_STEPS);
        view.pick(1, Complications.COMPLICATION_TYPE_STEPS);
        view.pick(2, Complications.COMPLICATION_TYPE_HEART_RATE);
        Test.assertEqual(view.shownType(1), Complications.COMPLICATION_TYPE_STEPS);
        Test.assertEqual(view.shownType(2), Complications.COMPLICATION_TYPE_HEART_RATE);
        return true;
    }

    // Picked fields awake and Always-On, and each slot in the editor's preview (left out of
    // the face, drawn alone).
    (:test)
    function drawsPickedFieldsAndEditingSlots(logger as Logger) as Boolean {
        var view = new BearingTestView();
        view.pick(1, Complications.COMPLICATION_TYPE_BODY_BATTERY);
        view.pick(2, Complications.COMPLICATION_TYPE_BATTERY);
        var dc = FaceTestUtil.renderEveryMode(view);
        for (var slot = 1; slot <= 2; slot++) {
            view.setEditingSlot(slot);
            view.onUpdate(dc);
            view.drawSlot(dc, slot);
        }
        view.setEditingSlot(null);
        view.onUpdate(dc);
        return true;
    }
}

// Bearing in the editor with the slots' fields picked by hand.
(:test)
class BearingTestView extends FaceView {

    function initialize() {
        FaceView.initialize(true);
    }

    function pick(slot as Number, type as Complications.Type) as Void {
        mSlotIds[slot] = new Complications.Id(type);
    }
}
