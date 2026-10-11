# FaceCore — shared code for every watch face in this repo

A new face is only a design: a `FaceView` that draws, its fonts, settings XML and editor config.
Everything else comes from here. ApexFace (the most tested face) is the reference for the fixes
the core carries.

## How faces use it

Not a Monkey Barrel: a shared source path. Each face's `monkey.jungle` (and `demo.jungle`) lists

    base.sourcePath = source;source-live;../FaceCore/source              # every face
    base.sourcePath = source;source-live;../FaceCore/source;../FaceCore/shop   # Shop Floor family

Why not a barrel: the core calls back into each face (`FaceDemo`, the face's `FaceView`), which a
barrel can't do; a barrel also needs its own manifest and product list kept in step with every face,
and versioning buys nothing when all faces live in one repo. The cost: a core change reaches every
face on its next build, so rebuild and test the faces that use it.

## Contents

| File | What |
|---|---|
| `source/FaceKit.mc` | geometry (454 design px), date/time text, colours, `prop`, `drawTracked`, `roundArc`; Always-On drift `aodShift` and fonts `loadFonts` / `strongResource` |
| `source/FaceData.mc` | sensor readings (steps, HR, body battery, weather, sun, sleep...), all nullable |
| `source/FaceEditor.mc` | on-watch editor (`WatchFaceConfig`) lookup and `FaceEditorDelegate` |
| `source/FaceCoreView.mc` | base `WatchFace`: scale, sleep state, `mData`, accent + date format settings, `alwaysOn()` |
| `source/FaceCoreApp.mc` | base `AppBase`: edit-mode flag, editor delegate, `onSettingsChanged` |
| `source/FaceKitTest.mc` | `(:test)` unit tests; they build into every face's test run |
| `shop/ShopKit.mc` | Shop Floor family: palette, `polar`, `bar`, `hexagon`, `dashed`, battery as volts |

Each face still supplies `FaceDemo` (`source-live/FaceDemo.mc` no-op, `tools/demo/FaceDemo.mc`
sample data): `FORCE_24H`, `FORCE_AOD`, `apply(data)`, `time(clock, now)`, `battery(real)`.

## Rules the core enforces

- **Fonts**: load with `FaceKit.loadFonts(ids, fallbacks)` in `loadFonts()`, never plain
  `WatchUi.loadResource`. On API 4+ a font is a graphics-pool reference the watch may purge; drawing
  with a purged one is a fatal, uncatchable Invalid Value (ApexFace on the fr970, 1.0.1).
- **Burn-in**: everything drawn in Always-On moves by `aodShift(clock.min)` (ApexFace's pattern):
  >= 14 px across and down in any 4 minutes (`FaceKitTest.aodShiftsMoveFarEnough`). Keep Always-On
  drawing `FaceKit.AOD_SHIFT_MAX` (10) design px inside the rim.
- **Settings**: `loadSettings()` reads the phone settings (`AccentColor`, `DateFormat`, then the face's
  `loadPhoneSettings()`), then the on-watch editor's choices on top: the editor wins when it has a
  value. Override `applyEditor` for more than the accent colour (call `FaceCoreView.applyEditor` first).

## A new face

    class FaceView extends FaceCoreView {
        function initialize(editMode as Boolean) {
            FaceCoreView.initialize(editMode, 0xFF6A13);   // default accent
            loadSettings();                                 // last, once members exist
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

From any face using the core, with the simulator open:

    monkeyc -f monkey.jungle -o bin\Test.prg -y C:\Users\dariu\developer_key -d fr970 --unit-test
    monkeydo bin\Test.prg fr970 /t
