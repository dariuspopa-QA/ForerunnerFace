import Toybox.Complications;
import Toybox.Lang;
import Toybox.Test;

// Tide's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module TideTest {

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
            "AccentColor" => [0x3FD0C9, 0xFF7A59, 0xB8E05A, 0x8E9BFF],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    // The two data slots stay on screen at every water level, the tag above the line.
    (:test)
    function slotsOnScreenAtEveryLevel(logger as Logger) as Boolean {
        var view = new TideTestView();
        var dc = FaceTestUtil.render(view);
        var levels = [null, 0, 5, 30, 50, 80, 100, 120] as Array<Number or Null>;
        for (var l = 0; l < levels.size(); l++) {
            view.setLevel(levels[l]);
            var ids = view.slots();
            Test.assertEqual(ids.size(), 2);
            for (var i = 0; i < ids.size(); i++) {
                var box = view.slotBox(ids[i]) as [Number, Number, Number, Number];
                Test.assertMessage(box[0] >= 0 && box[1] >= 0 && box[0] + box[2] <= dc.getWidth()
                    && box[1] + box[3] <= dc.getHeight(), "slot " + ids[i] + " off screen at " + levels[l]);
                view.drawSlot(dc, ids[i]);
            }
            var tag = view.slotBox(1) as [Number, Number, Number, Number];
            var line = view.slotBox(2) as [Number, Number, Number, Number];
            Test.assert(tag[1] < line[1]);
        }
        return true;
    }

    // Own field or none: the mockup's texts. Another field: "VALUE LABEL" in capitals, or
    // "--" until it has a value.
    (:test)
    function slotTexts(logger as Logger) as Boolean {
        var view = new TideTestView();
        Test.assertEqual(view.slotLine(1, Complications.COMPLICATION_TYPE_BODY_BATTERY, "52"), "52");
        Test.assert(view.slotLine(1, Complications.COMPLICATION_TYPE_BODY_BATTERY, null) == null);
        view.pick(1, Complications.COMPLICATION_TYPE_BODY_BATTERY);
        Test.assertEqual(view.slotLine(1, Complications.COMPLICATION_TYPE_BODY_BATTERY, "52"), "52");
        view.pick(2, Complications.COMPLICATION_TYPE_STEPS);
        Test.assertEqual(view.slotLine(2, Complications.COMPLICATION_TYPE_STEPS, "7,412 STEPS"), "7,412 STEPS");
        view.pick(1, Complications.COMPLICATION_TYPE_HEART_RATE);
        var text = view.slotLine(1, Complications.COMPLICATION_TYPE_BODY_BATTERY, "52") as String;
        Test.assert(!text.equals("52"));
        Test.assert(text.equals(text.toUpper()));
        logger.debug("HR slot: " + text);
        return true;
    }

    // Other fields in both slots, awake and Always-On, and each slot in the editor's
    // preview (left out of the face, drawn alone).
    (:test)
    function drawsPickedFieldsAndEditingSlot(logger as Logger) as Boolean {
        var view = new TideTestView();
        view.pick(1, Complications.COMPLICATION_TYPE_HEART_RATE);
        view.pick(2, Complications.COMPLICATION_TYPE_CALORIES);
        var dc = FaceTestUtil.renderEveryMode(view);
        var ids = view.slots();
        for (var i = 0; i < ids.size(); i++) {
            view.setEditingSlot(ids[i]);
            view.onUpdate(dc);
            view.drawSlot(dc, ids[i]);
        }
        view.setEditingSlot(null);
        view.onUpdate(dc);
        return true;
    }
}

// Tide in the editor with fields picked by hand and a set water level.
(:test)
class TideTestView extends FaceView {

    function initialize() {
        FaceView.initialize(true);
    }

    function pick(slot as Number, type as Complications.Type) as Void {
        mSlotIds[slot] = new Complications.Id(type);
    }

    function setLevel(bodyBattery as Number or Null) as Void {
        mData.bodyBattery = bodyBattery;
    }
}
