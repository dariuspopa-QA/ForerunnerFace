import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Shop Floor family tests (built into the five Shop Floor faces' test runs).
(:test)
module ShopKitTest {

    (:test)
    function batteryAsCarBatteryVolts(logger as Logger) as Boolean {
        Test.assertEqual(ShopKit.volts(0), "11.8");
        Test.assertEqual(ShopKit.volts(100), "12.7");
        Test.assertEqual(ShopKit.volts(84), "12.6");
        return true;
    }

    (:test)
    function missingReadingIsADash(logger as Logger) as Boolean {
        Test.assertEqual(ShopKit.orDash(null), "--");
        Test.assertEqual(ShopKit.orDash(72), "72");
        return true;
    }

    (:test)
    function polarFollowsTheClock(logger as Logger) as Boolean {
        var top = ShopKit.polar(0, 100, 0, 227, 227, 1.0f);
        var three = ShopKit.polar(90, 100, 0, 227, 227, 1.0f);
        Test.assert((top[0] - 227).abs() < 0.01f && (top[1] - 127).abs() < 0.01f);
        Test.assert((three[0] - 327).abs() < 0.01f && (three[1] - 227).abs() < 0.01f);
        return true;
    }

    (:test)
    function hexagonHasSixCornersOnItsRadius(logger as Logger) as Boolean {
        var pts = ShopKit.hexagon(227, 227, 20, 1.0f);
        Test.assertEqual(pts.size(), 6);
        for (var i = 0; i < 6; i++) {
            var dx = pts[i][0] - 227;
            var dy = pts[i][1] - 227;
            Test.assert((Math.sqrt(dx * dx + dy * dy) - 20).abs() < 0.01f);
        }
        return true;
    }
}
