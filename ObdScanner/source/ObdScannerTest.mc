import Toybox.Lang;
import Toybox.Test;

// ObdScanner's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module ObdScannerTest {

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
            "AccentColor" => [0xFFB000, 0x7DFF6A, 0x5FD3FF, 0xFF5A3C],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    // The four PID rows are the data slots: in table order, each box on its row, and a tap on
    // a row selects that row.
    (:test)
    function slotsAreThePidRows(logger as Logger) as Boolean {
        var view = new FaceView(true);
        FaceTestUtil.render(view);
        var ids = view.slots();
        Test.assertEqual(ids.size(), 4);
        var lastBottom = 0;
        for (var i = 0; i < ids.size(); i++) {
            var box = view.slotBox(ids[i]) as [Number, Number, Number, Number];
            Test.assertMessage(box[1] >= lastBottom, "slot " + ids[i] + " overlaps the one above");
            lastBottom = box[1] + box[3];
            Test.assertEqual(view.slotAt(box[0] + box[2] / 2, box[1] + box[3] / 2), ids[i]);
        }
        Test.assert(view.slotBox(5) == null);
        return true;
    }

    // With no field picked, each row keeps the face's own PID.
    (:test)
    function emptySlotsShowOwnPids(logger as Logger) as Boolean {
        var view = new FaceView(false);
        FaceTestUtil.render(view);
        Test.assertEqual(view.slotRow(1)[0], "HEART.RATE");
        Test.assertEqual(view.slotRow(2)[0], "STEP.COUNT");
        Test.assertEqual(view.slotRow(3)[0], "BATT.VOLT");
        Test.assertEqual(view.slotRow(4)[0], "STRESS.LOAD");
        return true;
    }

    // A picked field's label reads as a PID name.
    (:test)
    function fieldLabelsBecomePidNames(logger as Logger) as Boolean {
        Test.assertEqual(FaceView.pidName("BODY BATTERY"), "BODY.BATTERY");
        Test.assertEqual(FaceView.pidName("vo2 max"), "VO2.MAX");
        Test.assertEqual(FaceView.pidName("STEPS"), "STEPS");
        Test.assertEqual(FaceView.pidName(""), "PID");
        return true;
    }

    // The row the editor is previewing is left out of the face, then drawn alone.
    (:test)
    function drawsWithEachSlotInEditing(logger as Logger) as Boolean {
        var view = new FaceView(true);
        var ids = view.slots();
        for (var i = 0; i < ids.size(); i++) {
            view.setEditingSlot(ids[i]);
            var dc = FaceTestUtil.render(view);
            view.drawSlot(dc, ids[i]);
        }
        view.setEditingSlot(null);
        return true;
    }
}
