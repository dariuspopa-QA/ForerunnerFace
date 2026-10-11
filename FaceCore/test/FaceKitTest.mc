import Toybox.Lang;
import Toybox.Test;

// Unit tests for the shared core; they build into every face's test run
// (monkeyc --unit-test, then monkeydo <face>.prg fr970 /t with the simulator open).
module FaceKitTest {

    // Project rule: >= 14 px of Always-On movement across and down in any 4 minutes.
    (:test)
    function aodShiftsMoveFarEnough(logger as Logger) as Boolean {
        var span = FaceKit.minShiftSpan(FaceKit.AOD_SHIFTS, 4);
        logger.debug("min span " + span);
        return span[0] >= FaceKit.AOD_MIN_SPAN && span[1] >= FaceKit.AOD_MIN_SPAN;
    }

    (:test)
    function aodShiftsStayWithinMax(logger as Logger) as Boolean {
        for (var m = 0; m < 60; m++) {
            var s = FaceKit.aodShift(m);
            if (s[0].abs() > FaceKit.AOD_SHIFT_MAX || s[1].abs() > FaceKit.AOD_SHIFT_MAX) {
                return false;
            }
        }
        return true;
    }

    (:test)
    function aodShiftMovesEveryMinute(logger as Logger) as Boolean {
        for (var m = 0; m < 60; m++) {
            var a = FaceKit.aodShift(m);
            var b = FaceKit.aodShift(m + 1);
            Test.assertMessage(a[0] != b[0] || a[1] != b[1], "no move between minute " + m + " and " + (m + 1));
        }
        return true;
    }

    (:test)
    function dateTexts(logger as Logger) as Boolean {
        Test.assertEqual(FaceKit.dateRest(5, 9, 2026, FaceFormat.DATE_NAMED), "5 SEP");
        Test.assertEqual(FaceKit.dateRest(5, 9, 2026, FaceFormat.DATE_DMY), "05-09-2026");
        Test.assertEqual(FaceKit.dateRest(5, 9, 2026, FaceFormat.DATE_MDY), "09-05-2026");
        Test.assertEqual(FaceKit.dayName(1), "SUN");
        Test.assertEqual(FaceKit.monthName(12), "DEC");
        return true;
    }

    (:test)
    function numberTexts(logger as Logger) as Boolean {
        Test.assertEqual(FaceKit.thousands(999), "999");
        Test.assertEqual(FaceKit.thousands(8412), "8,412");
        Test.assertEqual(FaceKit.thousands(12005), "12,005");
        Test.assertEqual(FaceKit.durationText(45), "45m");
        Test.assertEqual(FaceKit.durationText(132), "2h 12m");
        return true;
    }

    (:test)
    function colourMix(logger as Logger) as Boolean {
        Test.assertEqual(FaceKit.mix(0xFFFFFF, 0x000000, 1.0f), 0xFFFFFF);
        Test.assertEqual(FaceKit.mix(0xFFFFFF, 0x000000, 0.0f), 0x000000);
        Test.assertEqual(FaceKit.mix(0xFF0000, 0x0000FF, 0.5f), 0x800080);
        return true;
    }

    (:test)
    function missingPropertyFallsBack(logger as Logger) as Boolean {
        return FaceKit.prop("NoSuchProperty", 42) == 42;
    }
}
