import Toybox.Lang;

// App lifecycle, settings and the on-watch editor come from FaceCoreApp (FaceCore/source).
class FlatRateApp extends FaceCoreApp {

    function initialize() {
        FaceCoreApp.initialize();
    }

    function createView(editMode as Boolean) as FaceCoreView {
        return new FaceView(editMode);
    }
}
