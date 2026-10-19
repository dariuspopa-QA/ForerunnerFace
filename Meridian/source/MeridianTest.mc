import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Meridian's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module MeridianTest {

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
            "AccentColor" => [0xFF6A3D, 0x3DDC97, 0x4DA3FF, 0xF2F0EA, 0xF2B544, 0xFF5C8A],
            "RingMode" => [0, 1],
            "Focus" => [0, 1, 2, 3, 4],
            "BarBattery" => [false, true],
            "BarSteps" => [false, true],
            "BarHeart" => [false, true],
            "BarStress" => [false, true],
            "BarResp" => [true, false],
            "BottomLine" => [0, 1, 2, 3],
            "ShowSeconds" => [true, false],
            "AodRing" => [true, false],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    // The focus row (1) and the bottom line (2) are the data slots: on screen, the focus row
    // above the line and apart from it and the bars, and a tap on each one's centre finds it.
    (:test)
    function twoDataSlots(logger as Logger) as Boolean {
        var view = new FaceView(true);
        var dc = FaceTestUtil.render(view);
        var s = dc.getWidth() / 454.0f;
        Test.assertEqual(view.slots().size(), 2);
        Test.assert(view.slotBox(0) == null);
        Test.assert(view.slotBox(3) == null);
        var focus = view.slotBox(1) as [Number, Number, Number, Number];
        var line = view.slotBox(2) as [Number, Number, Number, Number];
        Test.assertMessage(focus[1] + focus[3] < (306 - 2.5f) * s, "focus slot reaches the bars");
        Test.assertMessage(line[1] > (306 + 2.5f) * s, "bottom-line slot reaches the bars");
        for (var slot = 1; slot <= 2; slot++) {
            var box = view.slotBox(slot) as [Number, Number, Number, Number];
            Test.assertEqual(view.slotAt(box[0] + box[2] / 2, box[1] + box[3] / 2), slot);
        }
        return true;
    }

    // Without a picked field the slots show the face's own focus metric and line; a picked
    // field replaces them ("VO2 MAX 52.4" on the line, no icon; no bar fill in the focus row).
    (:test)
    function slotTextOrOwn(logger as Logger) as Boolean {
        var view = new FaceView(true);
        FaceTestUtil.render(view);
        for (var slot = 1; slot <= 2; slot++) {
            Test.assert(view.slotText(slot) == null);
        }
        Test.assertEqual(view.focusRow(null)[0], "BODY BATTERY");
        var row = view.focusRow(["52.4", "VO2 MAX"]);
        Test.assertEqual(row[0], "VO2 MAX");
        Test.assertEqual(row[1], "52.4");
        Test.assertEqual(row[2], "");
        Test.assert(row[3] == null);
        var line = view.lineOf(["52.4", "VO2 MAX"], 12.0f) as [Number, String];
        Test.assertEqual(line[0], -1);
        Test.assertEqual(line[1], "VO2 MAX 52.4");
        Test.assertEqual((view.lineOf(["7:42", ""], 12.0f) as [Number, String])[1], "7:42");
        return true;
    }

    // In the editor the face leaves out the slot being previewed, and the preview draws it
    // alone.
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

    // A tap on a mini bar makes its metric the focus; a tap elsewhere does nothing.
    (:test)
    function tapOnBarSwitchesFocus(logger as Logger) as Boolean {
        var view = new FaceView(false);
        var dc = FaceTestUtil.render(view);
        var s = dc.getWidth() / 454.0f;
        // the default four bars: battery, steps, heart, stress; the third is centred at x 251
        var hit = view.onFacePress((251 * s).toNumber(), (306 * s).toNumber());
        var miss = view.onFacePress((227 * s).toNumber(), (120 * s).toNumber());
        Application.Storage.deleteValue("tapFocus");
        Application.Storage.deleteValue("edFocus");
        return hit && !miss;
    }
}
