import Toybox.Lang;
import Toybox.Test;

// Core unit tests for FaceFormat (from ApexFace; compiled only into test builds).

(:test)
function dateTextUsesUpperCaseWeekdayUnpaddedDayAndMonth(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.dateText(2, 28, 9, 2026, FaceFormat.DATE_NAMED), "MON 28 SEP");
    return true;
}

(:test)
function dateTextCoversFirstAndLastWeekdayAndMonth(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.dateText(1, 1, 1, 2026, FaceFormat.DATE_NAMED), "SUN 1 JAN");
    Test.assertEqual(FaceFormat.dateText(7, 31, 12, 2026, FaceFormat.DATE_NAMED), "SAT 31 DEC");
    return true;
}

(:test)
function dateTextDoesNotPadSingleDigitDays(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.dateText(4, 9, 7, 2026, FaceFormat.DATE_NAMED), "WED 9 JUL");
    return true;
}

(:test)
function dateTextNumericFormatsPadDayAndMonth(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.dateText(4, 9, 7, 2026, FaceFormat.DATE_DMY), "WED 09-07-2026");
    Test.assertEqual(FaceFormat.dateText(4, 9, 7, 2026, FaceFormat.DATE_MDY), "WED 07-09-2026");
    Test.assertEqual(FaceFormat.dateText(2, 28, 9, 2026, FaceFormat.DATE_DMY), "MON 28-09-2026");
    Test.assertEqual(FaceFormat.dateText(2, 28, 9, 2026, FaceFormat.DATE_MDY), "MON 09-28-2026");
    return true;
}

(:test)
function dateFormatWatchFollowsUnitsAndExplicitChoicesWin(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.dateFormat(FaceFormat.DATE_WATCH, true), FaceFormat.DATE_MDY);
    Test.assertEqual(FaceFormat.dateFormat(FaceFormat.DATE_WATCH, false), FaceFormat.DATE_DMY);
    Test.assertEqual(FaceFormat.dateFormat(FaceFormat.DATE_NAMED, true), FaceFormat.DATE_NAMED);
    Test.assertEqual(FaceFormat.dateFormat(FaceFormat.DATE_DMY, true), FaceFormat.DATE_DMY);
    Test.assertEqual(FaceFormat.dateFormat(FaceFormat.DATE_MDY, false), FaceFormat.DATE_MDY);
    // unknown values (e.g. a stored setting from a future version) follow the watch
    Test.assertEqual(FaceFormat.dateFormat(9, false), FaceFormat.DATE_DMY);
    return true;
}

(:test)
function hourTextPadsIn24hAndMapsTo1To12In12h(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.hourText(7, false), "07");
    Test.assertEqual(FaceFormat.hourText(0, false), "00");
    Test.assertEqual(FaceFormat.hourText(0, true), "12");
    Test.assertEqual(FaceFormat.hourText(7, true), "7");
    Test.assertEqual(FaceFormat.hourText(12, true), "12");
    Test.assertEqual(FaceFormat.hourText(13, true), "1");
    Test.assertEqual(FaceFormat.hourText(23, true), "11");
    return true;
}

(:test)
function twoDigitsZeroPads(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.twoDigits(0), "00");
    Test.assertEqual(FaceFormat.twoDigits(7), "07");
    Test.assertEqual(FaceFormat.twoDigits(10), "10");
    Test.assertEqual(FaceFormat.twoDigits(23), "23");
    Test.assertEqual(FaceFormat.twoDigits(59), "59");
    return true;
}

(:test)
function thousandsGroupsDigits(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.thousands(0), "0");
    Test.assertEqual(FaceFormat.thousands(999), "999");
    Test.assertEqual(FaceFormat.thousands(1000), "1,000");
    Test.assertEqual(FaceFormat.thousands(8214), "8,214");
    Test.assertEqual(FaceFormat.thousands(1005007), "1,005,007");
    Test.assertEqual(FaceFormat.thousands(-1846), "-1,846");
    return true;
}

(:test)
function clockTextZeroPadsBothParts(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.clockText(7, 4, false), "07:04");
    Test.assertEqual(FaceFormat.clockText(19, 12, false), "19:12");
    Test.assertEqual(FaceFormat.clockText(19, 12, true), "7:12");
    return true;
}

(:test)
function numberTextShowsValueOrNoValue(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.numberText(58), "58");
    Test.assertEqual(FaceFormat.numberText(0), "0");
    Test.assertEqual(FaceFormat.numberText(null), "--");
    return true;
}

(:test)
function thousandsTextGroupsOrShowsNoValue(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.thousandsText(8214), "8,214");
    Test.assertEqual(FaceFormat.thousandsText(1846), "1,846");
    Test.assertEqual(FaceFormat.thousandsText(null), "--");
    return true;
}

(:test)
function recoveryTextAppendsHours(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.recoveryText(14), "14h");
    Test.assertEqual(FaceFormat.recoveryText(0), "0h");
    Test.assertEqual(FaceFormat.recoveryText(null), "--");
    return true;
}

(:test)
function percentTextTruncatesFractions(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.percentText(68), "68%");
    Test.assertEqual(FaceFormat.percentText(68.9f), "68%");
    Test.assertEqual(FaceFormat.percentText(100.0f), "100%");
    Test.assertEqual(FaceFormat.percentText(null), "--");
    return true;
}

(:test)
function distanceTextConvertsCentimetresToKilometres(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.distanceText(640000, false), "6.4");
    Test.assertEqual(FaceFormat.distanceText(0, false), "0.0");
    Test.assertEqual(FaceFormat.distanceText(1234567, false), "12.3");
    return true;
}

(:test)
function distanceTextConvertsCentimetresToMiles(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.distanceText(160934, true), "1.0");
    Test.assertEqual(FaceFormat.distanceText(1609344, true), "10.0");
    Test.assertEqual(FaceFormat.distanceText(null, true), "--");
    return true;
}

(:test)
function altitudeTextShowsWholeMetresOrFeet(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.altitudeText(312.7f, false), "312");
    Test.assertEqual(FaceFormat.altitudeText(312, false), "312");
    Test.assertEqual(FaceFormat.altitudeText(100, true), "328");
    Test.assertEqual(FaceFormat.altitudeText(-12.0f, false), "-12");
    Test.assertEqual(FaceFormat.altitudeText(null, false), "--");
    return true;
}

(:test)
function temperatureTextRoundsCelsius(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.temperatureText(17, false), "17°");
    Test.assertEqual(FaceFormat.temperatureText(17.4f, false), "17°");
    Test.assertEqual(FaceFormat.temperatureText(16.5f, false), "17°");
    Test.assertEqual(FaceFormat.temperatureText(-5.6f, false), "-6°");
    Test.assertEqual(FaceFormat.temperatureText(null, false), "--");
    return true;
}

(:test)
function temperatureTextConvertsToFahrenheit(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.temperatureText(0, true), "32°");
    Test.assertEqual(FaceFormat.temperatureText(100, true), "212°");
    Test.assertEqual(FaceFormat.temperatureText(-40, true), "-40°");
    return true;
}

(:test)
function complicationValueTextFormatsNumbers(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.complicationValueText(45, null), "45");
    Test.assertEqual(FaceFormat.complicationValueText(52.0f, null), "52");
    Test.assertEqual(FaceFormat.complicationValueText(52.36f, null), "52.4");
    Test.assertEqual(FaceFormat.complicationValueText(1013.27d, null), "1013.3");
    Test.assertEqual(FaceFormat.complicationValueText("GOOD", null), "GOOD");
    Test.assertEqual(FaceFormat.complicationValueText(null, "%"), "--");
    return true;
}

(:test)
function complicationValueTextAppendsOnlyStringUnits(logger as Logger) as Boolean {
    Test.assertEqual(FaceFormat.complicationValueText(97, "%"), "97%");
    Test.assertEqual(FaceFormat.complicationValueText(97, 3), "97");
    return true;
}

