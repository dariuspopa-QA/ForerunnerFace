import Toybox.Complications;
import Toybox.Lang;
import Toybox.Test;

// Bearing's own tests: its drawing in every display mode and with every value of its phone
// setting, and the battery text. The shared core is tested in FaceCore/test.
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
            "AccentColor" => [0x8CC8F0, 0x3DDC97, 0xF2B544, 0xFF6A3D]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    (:test)
    function batteryLevelAndText(logger as Logger) as Boolean {
        var view = new FaceView(false);
        var level = view.batteryLevel();
        Test.assert(level >= 0 && level <= 100);
        Test.assertEqual(view.batteryText(78), "78%");
        Test.assertEqual(view.batteryText(100), "100%");
        return true;
    }

    // Both slots sit on screen, a tap finds them, and there is no third.
    (:test)
    function slotsOnScreen(logger as Logger) as Boolean {
        var view = new BearingTestView();
        var dc = FaceTestUtil.render(view);
        for (var slot = 1; slot <= 2; slot++) {
            var box = view.slotBox(slot) as [Number, Number, Number, Number];
            Test.assert(box[0] >= 0 && box[1] >= 0 && box[0] + box[2] <= dc.getWidth() && box[1] + box[3] <= dc.getHeight());
            Test.assertEqual(view.slotAt(dc.getWidth() / 2, box[1] + box[3] / 2), slot);
        }
        Test.assert(view.slotBox(3) == null);
        return true;
    }

    // Battery / steps (or nothing picked) keep the face's own icons; another field shows as
    // label and value, "--" until it has a value.
    (:test)
    function slotFields(logger as Logger) as Boolean {
        var view = new BearingTestView();
        Test.assert(view.showsOwn(1, Complications.COMPLICATION_TYPE_BATTERY));
        view.pick(1, Complications.COMPLICATION_TYPE_BATTERY);
        view.pick(2, Complications.COMPLICATION_TYPE_STEPS);
        Test.assert(view.showsOwn(1, Complications.COMPLICATION_TYPE_BATTERY));
        Test.assert(view.showsOwn(2, Complications.COMPLICATION_TYPE_STEPS));
        view.pick(2, Complications.COMPLICATION_TYPE_HEART_RATE);
        Test.assert(!view.showsOwn(2, Complications.COMPLICATION_TYPE_STEPS));
        var t = view.fieldTexts(2);
        Test.assert(t[1].length() > 0);
        logger.debug("HR slot: " + t[0] + " " + t[1]);
        return true;
    }

    // Picked fields awake and Always-On, and each slot in the editor's preview.
    (:test)
    function drawsPickedFieldsAndEditingSlots(logger as Logger) as Boolean {
        var view = new BearingTestView();
        view.pick(1, Complications.COMPLICATION_TYPE_BODY_BATTERY);
        view.pick(2, Complications.COMPLICATION_TYPE_CALORIES);
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

// Bearing in the editor with slot fields picked by hand.
(:test)
class BearingTestView extends FaceView {

    function initialize() {
        FaceView.initialize(true);
    }

    function pick(slot as Number, type as Complications.Type or Null) as Void {
        if (type == null) {
            mSlotIds.remove(slot);
        } else {
            mSlotIds[slot] = new Complications.Id(type);
        }
    }
}
