import Toybox.Lang;

// App lifecycle, settings and the on-watch editor come from FaceCoreApp (FaceCore/face).
class BearingApp extends FaceCoreApp {

    function initialize() {
        FaceCoreApp.initialize();
    }

    function createView(editMode as Boolean) as FaceCoreView {
        return new FaceView(editMode);
    }
}
