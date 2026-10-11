import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Helpers for each face's own tests (<Face>/source/<Face>Test.mc): draw the face the way
// the watch would, in every display mode and with every value of its phone settings.
(:test)
module FaceTestUtil {

    // Lays out and draws the view once into an offscreen bitmap the size of this watch's
    // screen; returns its Dc.
    function render(view as WatchUi.WatchFace) as Graphics.Dc {
        var w = System.getDeviceSettings().screenWidth;
        var bitmap = Graphics.createBufferedBitmap({:width => w, :height => w}).get() as Graphics.BufferedBitmap;
        var dc = bitmap.getDc();
        view.onLayout(dc);
        view.onUpdate(dc);
        return dc;
    }

    // Awake, Always-On (wrist down) and awake again.
    function renderEveryMode(view as WatchUi.WatchFace) as Graphics.Dc {
        var dc = render(view);
        view.onEnterSleep();
        view.onUpdate(dc);
        view.onExitSleep();
        view.onUpdate(dc);
        return dc;
    }

    // Sets each property to each of its values in turn, reloads the settings (reload, called
    // with fromPhone when that isn't null) and draws awake and Always-On. The properties are
    // restored afterwards.
    function eachSettingValue(view as WatchUi.WatchFace, settings as Dictionary<String, Array>,
            reload as Method, fromPhone as Boolean or Null) as Void {
        var dc = render(view);
        var keys = settings.keys();
        for (var k = 0; k < keys.size(); k++) {
            var key = keys[k] as String;
            var saved = Application.Properties.getValue(key);
            var values = settings[key] as Array;
            for (var i = 0; i < values.size(); i++) {
                Application.Properties.setValue(key, values[i] as Application.Properties.ValueType);
                if (fromPhone != null) {
                    reload.invoke(fromPhone);
                } else {
                    reload.invoke();
                }
                view.onUpdate(dc);
                view.onEnterSleep();
                view.onUpdate(dc);
                view.onExitSleep();
            }
            Application.Properties.setValue(key, saved as Application.Properties.ValueType);
        }
        if (fromPhone != null) {
            reload.invoke(fromPhone);
        } else {
            reload.invoke();
        }
    }
}
