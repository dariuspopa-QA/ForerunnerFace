import Toybox.Lang;
import Toybox.Test;

// SocketSet's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module SocketSetTest {

    (:test)
    function drawsEveryMode(logger as Logger) as Boolean {
        FaceTestUtil.renderEveryMode(new FaceView(false));
        // Inside the on-watch editor (never Always-On there)
        FaceTestUtil.renderEveryMode(new FaceView(true));
        return true;
    }

    // The three readouts are the data slots: side by side left to right, apart, and a tap on
    // each one's centre finds it.
    (:test)
    function threeReadoutSlots(logger as Logger) as Boolean {
        var view = new FaceView(true);
        FaceTestUtil.render(view);
        Test.assertEqual(view.slots().size(), 3);
        Test.assert(view.slotBox(0) == null);
        Test.assert(view.slotBox(4) == null);
        var prevRight = -1;
        for (var slot = 1; slot <= 3; slot++) {
            var box = view.slotBox(slot) as [Number, Number, Number, Number];
            Test.assertMessage(box[0] > prevRight, "slot " + slot + " overlaps the one before");
            prevRight = box[0] + box[2];
            Test.assertEqual(view.slotAt(box[0] + box[2] / 2, box[1] + box[3] / 2), slot);
        }
        return true;
    }

    // Without a picked field each slot shows the face's own reading.
    (:test)
    function emptySlotsShowOwnReadings(logger as Logger) as Boolean {
        var view = new FaceView(true);
        FaceTestUtil.render(view);
        var labels = ["HR", "BATT", "ODO"];
        for (var slot = 1; slot <= 3; slot++) {
            Test.assert(view.slotText(slot) == null);
            Test.assertEqual(view.ownReadout(slot)[1], labels[slot - 1]);
        }
        Test.assert(view.ownReadout(2)[0].find("V") != null);
        return true;
    }

    // In the editor, the face leaves out the slot being previewed and the preview draws it alone.
    (:test)
    function drawsWhileEachSlotIsEdited(logger as Logger) as Boolean {
        var view = new FaceView(true);
        var dc = FaceTestUtil.render(view);
        for (var slot = 1; slot <= 3; slot++) {
            view.setEditingSlot(slot);
            view.onUpdate(dc);
            view.drawSlot(dc, slot);
        }
        view.setEditingSlot(null);
        view.onUpdate(dc);
        return true;
    }

    (:test)
    function drawsEverySettingValue(logger as Logger) as Boolean {
        var view = new FaceView(false);
        FaceTestUtil.eachSettingValue(view, {
            "AccentColor" => [0xFF6A13, 0xFFD400, 0x3AD0FF, 0xE83A3A],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }
}
