import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Helpers shared by the unit tests (test builds only).
(:test)
module ApexTestUtil {

    // Glyph sets of the custom fonts (CLAUDE.md, Fonts)
    const VALUE_GLYPHS = "0123456789,.:%°h-";
    const LABEL_GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ ";
    const DATE_GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";

    function onlyGlyphs(text as String, glyphs as String) as Boolean {
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (glyphs.find(chars[i].toString()) == null) {
                return false;
            }
        }
        return true;
    }

    function near(actual as Numeric, expected as Numeric, tolerance as Numeric) as Boolean {
        return (actual - expected).abs() <= tolerance;
    }

    function assertNear(actual as Numeric, expected as Numeric, tolerance as Numeric, what as String) as Void {
        Test.assertMessage(near(actual, expected, tolerance),
            what + ": expected " + expected + ", got " + actual);
    }

    // Lays out and draws the view once into an offscreen 454 x 454 bitmap; returns its Dc.
    function render(view as ApexFaceView) as Graphics.Dc {
        var bitmap = Graphics.createBufferedBitmap({:width => 454, :height => 454}).get() as Graphics.BufferedBitmap;
        var dc = bitmap.getDc();
        view.onLayout(dc);
        view.onUpdate(dc);
        return dc;
    }

    function saveProperties(keys as Array<String>) as Dictionary {
        var saved = {};
        for (var i = 0; i < keys.size(); i++) {
            saved[keys[i]] = Application.Properties.getValue(keys[i]);
        }
        return saved;
    }

    function restoreProperties(saved as Dictionary) as Void {
        var keys = saved.keys();
        for (var i = 0; i < keys.size(); i++) {
            Application.Properties.setValue(keys[i] as String, saved[keys[i]] as Application.Properties.ValueType);
        }
    }

    // Test.assertEqual, but null-safe and with the values in the failure message.
    function assertEqual(actual as Object or Null, expected as Object or Null) as Void {
        var same = (actual == null || expected == null) ? actual == expected : actual.equals(expected);
        Test.assertMessage(same, "expected " + expected + ", got " + actual);
    }
}
