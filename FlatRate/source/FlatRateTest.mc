import Toybox.Complications;
import Toybox.Lang;
import Toybox.Test;

// FlatRate's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module FlatRateTest {

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
            "AccentColor" => [0xD7FF1F, 0xFFD400, 0xFF6A13, 0x3AD0FF],
            "DateFormat" => [0, 1, 2, 3],
            "ShiftStart" => [300, 330, 360, 390, 420, 450, 480, 510, 540, 570, 600, 630, 660],
            "ShiftLength" => [240, 360, 420, 480, 540, 600, 720],
            "BreakTime" => [-1, 600, 630, 660, 690, 720, 750, 780, 810, 840],
            "RepairOrder" => [4471, 0],
            "Bay" => [0, 99, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    // The slot sits on screen and a tap on it selects it.
    (:test)
    function slotOnScreen(logger as Logger) as Boolean {
        var view = new FlatRateTestView();
        var dc = FaceTestUtil.render(view);
        var box = view.slotBox(1) as [Number, Number, Number, Number];
        Test.assert(box[0] >= 0 && box[1] >= 0 && box[0] + box[2] <= dc.getWidth() && box[1] + box[3] <= dc.getHeight());
        Test.assertEqual(view.slotAt(dc.getWidth() / 2, box[1] + box[3] / 2), 1);
        Test.assert(view.slotBox(2) == null);
        return true;
    }

    // The face's own reading while the slot holds its own field or none; another field in
    // capitals, or "--" until it has a value.
    (:test)
    function slotTexts(logger as Logger) as Boolean {
        var view = new FlatRateTestView();
        var mine = view.bottomReading();
        view.pick(Complications.COMPLICATION_TYPE_HEART_RATE);
        Test.assertEqual(view.bottomReading(), mine);
        view.pick(Complications.COMPLICATION_TYPE_CALORIES);
        var text = view.bottomReading();
        Test.assert(!text.equals(mine));
        Test.assert(text.equals(text.toUpper()));
        logger.debug("own: " + mine + ", calories: " + text);
        return true;
    }

    // A picked field awake and Always-On, and the slot in the editor's preview (left out
    // of the face, drawn alone).
    (:test)
    function drawsPickedFieldAndEditingSlot(logger as Logger) as Boolean {
        var view = new FlatRateTestView();
        view.pick(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        var dc = FaceTestUtil.renderEveryMode(view);
        view.setEditingSlot(1);
        view.onUpdate(dc);
        view.drawSlot(dc, 1);
        view.setEditingSlot(null);
        view.onUpdate(dc);
        return true;
    }
}

// FlatRate in the editor with the slot's field picked by hand.
(:test)
class FlatRateTestView extends FaceView {

    function initialize() {
        FaceView.initialize(true);
    }

    function pick(type as Complications.Type) as Void {
        mSlotIds[1] = new Complications.Id(type);
    }
}
