import Toybox.Lang;
import Toybox.Test;

// TachCluster's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module TachClusterTest {

    // The ODO line (1) and the dial caption (2) are the data slots: the caption above the LCD,
    // apart from it, and a tap on each one's centre finds it.
    (:test)
    function odoAndCaptionSlots(logger as Logger) as Boolean {
        var view = new FaceView(true);
        FaceTestUtil.render(view);
        Test.assertEqual(view.slots().size(), 2);
        Test.assert(view.slotBox(0) == null);
        Test.assert(view.slotBox(3) == null);
        var odo = view.slotBox(1) as [Number, Number, Number, Number];
        var caption = view.slotBox(2) as [Number, Number, Number, Number];
        Test.assertMessage(caption[1] + caption[3] < odo[1], "caption slot overlaps the ODO slot");
        for (var slot = 1; slot <= 2; slot++) {
            var box = view.slotBox(slot) as [Number, Number, Number, Number];
            Test.assertEqual(view.slotAt(box[0] + box[2] / 2, box[1] + box[3] / 2), slot);
        }
        return true;
    }

    // Without a picked field the slots show the face's own text: steps as ODO, the dial's unit.
    (:test)
    function emptySlotsShowOwnText(logger as Logger) as Boolean {
        var view = new FaceView(true);
        FaceTestUtil.render(view);
        Test.assert(view.slotText(1) == null);
        Test.assert(view.slotText(2) == null);
        Test.assertEqual(view.ownReadout(1)[1], "ODO");
        Test.assertEqual(view.ownReadout(1)[0].length(), 6);
        Test.assertEqual(view.ownReadout(2)[0], "r/min");
        return true;
    }

    // In the editor, the face leaves out the slot being previewed and the preview draws it alone.
    (:test)
    function drawsWhileEachSlotIsEdited(logger as Logger) as Boolean {
        var view = new FaceView(true);
        var dc = FaceTestUtil.render(view);
        for (var slot = 1; slot <= 2; slot++) {
            view.setEditingSlot(slot);
            view.onUpdate(dc);
            view.drawSlot(dc, slot);
        }
        view.setEditingSlot(null);
        view.onUpdate(dc);
        return true;
    }

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
            "AccentColor" => [0xFF6A13, 0xFFD400, 0x3AD0FF, 0xE83A3A]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }
}
