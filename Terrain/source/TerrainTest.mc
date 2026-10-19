import Toybox.Complications;
import Toybox.Lang;
import Toybox.Test;

// Terrain's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module TerrainTest {

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
            "AccentColor" => [0xFF6A3D, 0x3DDC97, 0x4DA3FF, 0xF2B544],
            "DateFormat" => [0, 1, 2, 3]
        }, view.method(:phoneSettingsChanged), null);
        return true;
    }

    // The sun line slot sits on screen, below the time and above the sky arc's top.
    (:test)
    function slotOnScreen(logger as Logger) as Boolean {
        var view = new TerrainTestView();
        var dc = FaceTestUtil.render(view);
        var box = view.slotBox(1) as [Number, Number, Number, Number];
        Test.assert(box[0] >= 0 && box[1] >= 0 && box[0] + box[2] <= dc.getWidth() && box[1] + box[3] <= dc.getHeight());
        Test.assertEqual(view.slotAt(dc.getWidth() / 2, box[1] + box[3] / 2), 1);
        Test.assert(view.slotBox(2) == null);
        return true;
    }

    // Sunset or nothing: the face's own line. Another field: "value label" in lower case
    // (the Small font has no capitals), or "--" until it has a value.
    (:test)
    function slotTexts(logger as Logger) as Boolean {
        var view = new TerrainTestView();
        view.setSun(6.5f, 19.0f);
        Test.assertEqual(view.sunLineText(12.0f), "sunset " + FaceKit.clockText(19.0f));
        Test.assertEqual(view.sunLineText(22.0f), "sunrise " + FaceKit.clockText(6.5f));
        view.pick(Complications.COMPLICATION_TYPE_SUNSET);
        Test.assertEqual(view.sunLineText(12.0f), "sunset " + FaceKit.clockText(19.0f));
        view.pick(Complications.COMPLICATION_TYPE_HEART_RATE);
        var text = view.sunLineText(12.0f) as String;
        Test.assert(!text.equals("sunset " + FaceKit.clockText(19.0f)));
        Test.assert(text.equals(text.toLower()));
        logger.debug("HR slot: " + text);
        view.setSun(null, null);
        view.pick(null);
        Test.assert(view.sunLineText(12.0f) == null);
        return true;
    }

    // A picked field awake and Always-On, and the slot in the editor's preview (left out
    // of the face, drawn alone).
    (:test)
    function drawsPickedFieldAndEditingSlot(logger as Logger) as Boolean {
        var view = new TerrainTestView();
        view.pick(Complications.COMPLICATION_TYPE_CALORIES);
        var dc = FaceTestUtil.renderEveryMode(view);
        view.setEditingSlot(1);
        view.onUpdate(dc);
        view.drawSlot(dc, 1);
        view.setEditingSlot(null);
        view.onUpdate(dc);
        return true;
    }
}

// Terrain in the editor with the slot's field picked by hand and set sun times.
(:test)
class TerrainTestView extends FaceView {

    function initialize() {
        FaceView.initialize(true);
    }

    function pick(type as Complications.Type or Null) as Void {
        if (type == null) {
            mSlotIds.remove(1);
        } else {
            mSlotIds[1] = new Complications.Id(type);
        }
    }

    function setSun(rise as Float or Null, set as Float or Null) as Void {
        mData.sunrise = rise;
        mData.sunset = set;
    }
}
