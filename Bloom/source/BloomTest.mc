import Toybox.Complications;
import Toybox.Lang;
import Toybox.Test;

// Bloom's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module BloomTest {

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
            "Palette" => [0, 1, 2, 3, 4, 5, 6, 7],
            "Highlight" => [0xFF8A3D, 0xFF4A4A, 0xFFD23D, 0xC8FF2E, 0x4FD1FF, 0xFF5AC8, 0xF3F1EC],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    // The slot sits on screen below the shape and a tap on it selects it.
    (:test)
    function slotOnScreen(logger as Logger) as Boolean {
        var view = new BloomTestView();
        var dc = FaceTestUtil.render(view);
        var box = view.slotBox(1) as [Number, Number, Number, Number];
        Test.assert(box[0] >= 0 && box[1] >= 0 && box[0] + box[2] <= dc.getWidth() && box[1] + box[3] <= dc.getHeight());
        Test.assertEqual(view.slotAt(dc.getWidth() / 2, box[1] + box[3] / 2), 1);
        Test.assert(view.slotBox(2) == null);
        return true;
    }

    // Heart rate or nothing: "72" over "HR". Another field: its value over its key, in
    // capitals, or "--" until it has a value.
    (:test)
    function slotTexts(logger as Logger) as Boolean {
        var view = new BloomTestView();
        view.setHeartRate(72);
        Test.assertEqual((view.bottomLabel() as [String, String])[0], "72");
        Test.assertEqual((view.bottomLabel() as [String, String])[1], "HR");
        view.pick(Complications.COMPLICATION_TYPE_HEART_RATE);
        Test.assertEqual((view.bottomLabel() as [String, String])[1], "HR");
        view.setHeartRate(null);
        view.pick(Complications.COMPLICATION_TYPE_CALORIES);
        var t = view.bottomLabel() as [String, String];
        Test.assert(t[0].equals(t[0].toUpper()) && t[1].equals(t[1].toUpper()));
        Test.assert(t[1].length() <= 12);
        logger.debug("calories: " + t[0] + " / " + t[1]);
        return true;
    }

    // A picked field awake and Always-On, and the slot in the editor's preview (left out
    // of the face, drawn alone).
    (:test)
    function drawsPickedFieldAndEditingSlot(logger as Logger) as Boolean {
        var view = new BloomTestView();
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

// Bloom in the editor with the slot's field picked by hand.
(:test)
class BloomTestView extends FaceView {

    function initialize() {
        FaceView.initialize(true);
    }

    function pick(type as Complications.Type) as Void {
        mSlotIds[1] = new Complications.Id(type);
    }

    function setHeartRate(bpm as Number or Null) as Void {
        mData.hrOverride = bpm;
    }
}
