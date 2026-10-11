# FaceCore — shared code for every watch face in this repo

A new face is only a design: a `FaceView` that draws, its fonts, settings XML and editor config.
Everything else comes from here. ApexFace (the most tested face) is the reference for the fixes
the core carries, and its generic code and tests now live here.

## How faces use it

Not a Monkey Barrel: shared source paths. Each face's `monkey.jungle` (and `demo.jungle`) lists the
folders it needs:

| Folder | What | Used by |
|---|---|---|
| `kit/` | `FaceKit` (geometry, colours, `prop`, fonts, Always-On drift, device-aware text), `FaceFormat` (pure text: dates, hours, numbers, units), `FaceEditor` (editor lookup, `pick`) | every face |
| `face/` | `FaceCoreView`, `FaceCoreApp`, `FaceEditorDelegate`, `FaceData` (sensor readings) | design-only faces: Shop Floor, Tide, Bloom, Meridian, Terrain |
| `slots/` | `EditorConfig.mc`: on-watch editor with tappable data slots (complications) | GoalBars, MinimalFace, PulseRings, TrainingPulse |
| `shop/` | `ShopKit` + `ShopKitTest`: Shop Floor family palette and shapes | SocketSet, TachCluster, ObdScanner, LugStar, FlatRate |
| `test/` | core tests (`FaceKitTest`, `FaceFormatTest`) and `FaceTestUtil` for face tests | every face |

    base.sourcePath = source;source-live;../FaceCore/kit;../FaceCore/face;../FaceCore/test   # e.g. Tide

ApexFace takes only `kit` and `test`: its view, app and editor delegate stay its own (night mode,
complication slots, partial updates, 66 products incl. MIP), and `face/` would only add code memory.

Why not a barrel: the core calls back into each face (`FaceDemo`, the face's view), which a barrel
can't do; a barrel also needs its own manifest and product list kept in step with every face, and
versioning buys nothing when all faces live in one repo. The cost: a core change reaches every face
on its next build, so run every face's tests after changing it. ApexFace builds with `-l 3` (strict
typing) in its device tests, so `kit/` and `test/` must compile strictly.

Each face supplies `FaceDemo` (`source-live/FaceDemo.mc`): at least `FORCE_24H` and `FORCE_AOD`;
the design-only faces also `apply(data)`, `time(clock, now)` and (Shop Floor) `battery(real)`, with
sample values in `tools/demo/FaceDemo.mc` for `demo.jungle`.

## Rules the core enforces

- **Fonts**: load with `FaceKit.loadFonts(ids, fallbacks)` (or `FaceKit.strongResource`), never plain
  `WatchUi.loadResource`. On API 4+ a font is a graphics-pool reference the watch may purge; drawing
  with a purged one is a fatal, uncatchable Invalid Value (ApexFace on the fr970, 1.0.1).
- **Burn-in**: everything drawn in Always-On moves by `FaceKit.aodShift(clock.min)` (ApexFace's
  pattern, design px of 454; scale by `r / FaceKit.C` on faces drawn in screen units): >= 14 px across
  and down in any 4 minutes (`FaceKitTest.aodShiftsMoveFarEnough`). Keep Always-On drawing
  `FaceKit.AOD_SHIFT_MAX` (10) design px inside the rim.
- **Settings** (`FaceCoreView`): `loadSettings()` reads the phone settings (`AccentColor`,
  `DateFormat`, then the face's `loadPhoneSettings()`), then the on-watch editor's choices on top: the
  editor wins when it has a value. Override `applyEditor` for more than the accent colour (call
  `FaceCoreView.applyEditor` first). Faces where whichever side changed last should win use
  `FaceEditor.pick` (Meridian) or keep their own rule (Bloom, GoalBars, PulseRings).

## A new face

    class FaceView extends FaceCoreView {
        function initialize(editMode as Boolean) {
            FaceCoreView.initialize(editMode, 0xFF6A13, FaceFormat.DATE_NAMED);   // default accent, date
            loadSettings();                                                       // last, once members exist
        }
        function loadFonts() as Void {
            var f = FaceKit.loadFonts([Rez.Fonts.Time] as Array<ResourceId>, [Graphics.FONT_NUMBER_HOT] as Array<FontType>);
            mFontTime = f[0];
        }
        function onUpdate(dc as Dc) as Void {
            mData.refresh();
            if (alwaysOn()) { var s = aodShift(clock.min); ... return; }
            ...
        }
    }

    class MyFaceApp extends FaceCoreApp {
        function initialize() { FaceCoreApp.initialize(); }
        function createView(editMode as Boolean) as FaceCoreView { return new FaceView(editMode); }
    }

## Tests

Two layers. The core's tests (`test/`, plus `shop/ShopKitTest.mc` for that family) build into every
face that uses the folder. Each face's `source/<Name>Test.mc` covers only what that face customizes:
it draws every display mode (awake, Always-On, inside the editor) and every value of each of its
phone settings (`FaceTestUtil`); ApexFace keeps its own larger suite (layout, metrics, per-watch).

From a face folder, with the simulator open:

    monkeyc -f monkey.jungle -o bin\Test.prg -y C:\Users\dariu\developer_key -d fr970 --unit-test
    monkeydo bin\Test.prg fr970 /t
