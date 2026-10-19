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
| `face/` | `FaceCoreView`, `FaceCoreApp`, `FaceEditorDelegate`, `FaceData` (sensor readings), `FaceSlots` (editor data slots) | design-only faces: Shop Floor, Tide, Bloom, Meridian, Terrain |
| `slots/` | `EditorConfig.mc`: on-watch editor with tappable data slots (complications) for faces with their own view | GoalBars, MinimalFace, PulseRings, TrainingPulse |
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

## Every round watch (66 products, as ApexFace)

All faces except ApexFace's own copy ship to `tools/products.ps1`'s list: every round watch on
API 5.0+, 218-466 px, AMOLED and MIP (`tools\set-products.ps1 -Face <name>` writes it into a
manifest). What that takes, in the core and in each face:

- **Fonts for 9 screen sizes**: `tools\make-fonts.ps1 -Face <name>` (each face's
  `tools\make-fonts.ps1` calls it) builds `resources-round-<W>x<W>/fonts/` for 218, 240, 260, 280
  (MIP) and 360, 390, 416, 454, 466 (AMOLED). A font-table minimum is for the 360 px screen;
  smaller screens scale it down to 10 px at least. MIP gets 1-bit glyphs below 20 px. A 7th
  font-table entry `'italic'` slants the glyphs (TachCluster's dial numbers).
  `FaceDeviceTest.fontsLoadOnThisScreen` fails if any font falls back to a system font.
- **On-watch editor**: the config is in `resources/configs/watchface.xml` for every product (the
  firmware ignores it where there is no editor). Data types in it must exist on every product
  (checked for GoalBars and MinimalFace's slots against each device's API).
- **MIP screens** (`mAmoled` false, from `requiresBurnInProtection`): no Always-On, the normal face
  stays on and is redrawn once a minute, so seconds show only while awake (`showSeconds()`).
  64 colours: draw with `ink(color)`, which turns near-greys into one neutral grey (a dark grey
  with slightly different channels otherwise rounds to navy or brown, `FaceColor.mipGrey`).
  Faces with tinted darks set their own MIP palette in `onLayout` (Meridian: the mockup's MIP
  theme; Terrain).
- **No texture fills on 12 watches** (Forerunner 165 / 255 / 70, vivoactive 5, Instinct 3
  AMOLED, Approach S50, Descent G2: `enhancedGraphicSupport` false, `Dc has :setFill` false).
  Tide and Bloom draw their dark-on-colour text clipped to strips there instead.
- **Small screens**: text minimums make text relatively wider than in the mockup; faces move
  labels inward (Bloom), drop letter-spacing (`fitTracking`), use short texts (OBD Scanner) or
  lay out from measured widths (Tach Cluster).
- **Data slots** (on-watch editor complications, `face/FaceSlots.mc`): list them in
  `resources/configs/watchface.xml` as `<complication id="N" allowAny="true"/>` (or a typed list
  with a default), override `slots()`, `slotBox(slot)` and `drawSlot(dc, slot)`, and draw
  `slotText(slot)` (`[value, LABEL]`, null = show the face's own value) in every slot except
  `mEditingSlot`. `FaceCoreView.applyEditor` reads the picked fields and subscribes to them;
  faces whose `applyEditor` doesn't call it (Bloom, Meridian) call `applySlots(settings)` (Bloom also in `loadSettings`).
  `FaceEditorDelegate` previews the selected slot and selects slots by tap in the editor.
  Core tests: `face/FaceSlotsTest.mc` (hit-testing, and every slot box of the face on screen).
- **Taps** (touch watches): `FaceEditorDelegate.onPress` passes taps to `onFacePress(x, y)`
  (Meridian: tap a bar to switch the focus metric).

## Tools (FaceCore/tools, PowerShell, simulator open and visible for the ones that render)

| Script | What |
|---|---|
| `products.ps1` | the 66 products, screen sizes, the 16-watch test matrix, one watch per screen size |
| `set-products.ps1 -Face X` | writes the product list into X's manifest |
| `make-fonts.ps1 -Face X` | bitmap fonts for every screen size from X's `tools/font-table.ps1` |
| `run-device-tests.ps1 -Face X,Y [-Devices a,b] [-Jobs 4]` | the faces' unit tests (face, core, FaceDeviceTest) on the 16-watch matrix; builds in parallel, runs one by one, restarts a hung simulator |
| `shot.ps1 -Face X -Device d -Out p.png [-Props -Demo -Data -Hour -Min -Sec -Aod]` | one simulator capture of the demo build with given property defaults / demo values; faces without a demo build get `ShotData.mc.txt` (fixed time and readings) in a scratch copy |
| `capture-screens.ps1 -Face X` | X on one watch per screen size into `store/faces/devices/`, then `compose-devices.ps1` (store/watches: per-screen screenshots and the overview) |
| `store-shots.ps1 -Face X` | the shots in X's `store/store-config.ps1`, then `compose-store.ps1` (icon, cover, screenshots, showcase, hero) |
| `store-watches.txt` | the supported-watches block of every store description (`{{WATCHES}}`) |
| `package.ps1 -Face X` | the store package `dist/<Name>-<version>.iq` (all 66 products) |

Never run two of the simulator scripts at once: they share the one simulator.

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
