import Toybox.Lang;
import Toybox.Test;

// Unit tests (compiled only into test builds). Run with the "Monkey C: Run Tests" command.

(:test)
function dateTextUsesUpperCaseWeekdayUnpaddedDayAndMonth(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.dateText(2, 28, 9), "MON 28 SEP");
    return true;
}

(:test)
function dateTextCoversFirstAndLastWeekdayAndMonth(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.dateText(1, 1, 1), "SUN 1 JAN");
    ApexTestUtil.assertEqual(ApexFormat.dateText(7, 31, 12), "SAT 31 DEC");
    return true;
}

(:test)
function dateTextDoesNotPadSingleDigitDays(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.dateText(4, 9, 7), "WED 9 JUL");
    return true;
}

(:test)
function twoDigitsZeroPads(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.twoDigits(0), "00");
    ApexTestUtil.assertEqual(ApexFormat.twoDigits(7), "07");
    ApexTestUtil.assertEqual(ApexFormat.twoDigits(10), "10");
    ApexTestUtil.assertEqual(ApexFormat.twoDigits(23), "23");
    ApexTestUtil.assertEqual(ApexFormat.twoDigits(59), "59");
    return true;
}

(:test)
function thousandsGroupsDigits(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.thousands(0), "0");
    ApexTestUtil.assertEqual(ApexFormat.thousands(999), "999");
    ApexTestUtil.assertEqual(ApexFormat.thousands(1000), "1,000");
    ApexTestUtil.assertEqual(ApexFormat.thousands(8214), "8,214");
    ApexTestUtil.assertEqual(ApexFormat.thousands(1005007), "1,005,007");
    ApexTestUtil.assertEqual(ApexFormat.thousands(-1846), "-1,846");
    return true;
}

(:test)
function clockTextZeroPadsBothParts(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.clockText(7, 4), "07:04");
    ApexTestUtil.assertEqual(ApexFormat.clockText(19, 12), "19:12");
    return true;
}

(:test)
function numberTextShowsValueOrNoValue(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.numberText(58), "58");
    ApexTestUtil.assertEqual(ApexFormat.numberText(0), "0");
    ApexTestUtil.assertEqual(ApexFormat.numberText(null), "--");
    return true;
}

(:test)
function thousandsTextGroupsOrShowsNoValue(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.thousandsText(8214), "8,214");
    ApexTestUtil.assertEqual(ApexFormat.thousandsText(1846), "1,846");
    ApexTestUtil.assertEqual(ApexFormat.thousandsText(null), "--");
    return true;
}

(:test)
function recoveryTextAppendsHours(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.recoveryText(14), "14h");
    ApexTestUtil.assertEqual(ApexFormat.recoveryText(0), "0h");
    ApexTestUtil.assertEqual(ApexFormat.recoveryText(null), "--");
    return true;
}

(:test)
function percentTextTruncatesFractions(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.percentText(68), "68%");
    ApexTestUtil.assertEqual(ApexFormat.percentText(68.9f), "68%");
    ApexTestUtil.assertEqual(ApexFormat.percentText(100.0f), "100%");
    ApexTestUtil.assertEqual(ApexFormat.percentText(null), "--");
    return true;
}

(:test)
function distanceTextConvertsCentimetresToKilometres(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.distanceText(640000, false), "6.4");
    ApexTestUtil.assertEqual(ApexFormat.distanceText(0, false), "0.0");
    ApexTestUtil.assertEqual(ApexFormat.distanceText(1234567, false), "12.3");
    return true;
}

(:test)
function distanceTextConvertsCentimetresToMiles(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.distanceText(160934, true), "1.0");
    ApexTestUtil.assertEqual(ApexFormat.distanceText(1609344, true), "10.0");
    ApexTestUtil.assertEqual(ApexFormat.distanceText(null, true), "--");
    return true;
}

(:test)
function altitudeTextShowsWholeMetresOrFeet(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.altitudeText(312.7f, false), "312");
    ApexTestUtil.assertEqual(ApexFormat.altitudeText(312, false), "312");
    ApexTestUtil.assertEqual(ApexFormat.altitudeText(100, true), "328");
    ApexTestUtil.assertEqual(ApexFormat.altitudeText(-12.0f, false), "-12");
    ApexTestUtil.assertEqual(ApexFormat.altitudeText(null, false), "--");
    return true;
}

(:test)
function temperatureTextRoundsCelsius(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.temperatureText(17, false), "17°");
    ApexTestUtil.assertEqual(ApexFormat.temperatureText(17.4f, false), "17°");
    ApexTestUtil.assertEqual(ApexFormat.temperatureText(16.5f, false), "17°");
    ApexTestUtil.assertEqual(ApexFormat.temperatureText(-5.6f, false), "-6°");
    ApexTestUtil.assertEqual(ApexFormat.temperatureText(null, false), "--");
    return true;
}

(:test)
function temperatureTextConvertsToFahrenheit(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.temperatureText(0, true), "32°");
    ApexTestUtil.assertEqual(ApexFormat.temperatureText(100, true), "212°");
    ApexTestUtil.assertEqual(ApexFormat.temperatureText(-40, true), "-40°");
    return true;
}

(:test)
function complicationValueTextFormatsNumbers(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.complicationValueText(45, null), "45");
    ApexTestUtil.assertEqual(ApexFormat.complicationValueText(52.0f, null), "52");
    ApexTestUtil.assertEqual(ApexFormat.complicationValueText(52.36f, null), "52.4");
    ApexTestUtil.assertEqual(ApexFormat.complicationValueText(1013.27d, null), "1013.3");
    ApexTestUtil.assertEqual(ApexFormat.complicationValueText("GOOD", null), "GOOD");
    ApexTestUtil.assertEqual(ApexFormat.complicationValueText(null, "%"), "--");
    return true;
}

(:test)
function complicationValueTextAppendsOnlyStringUnits(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexFormat.complicationValueText(97, "%"), "97%");
    ApexTestUtil.assertEqual(ApexFormat.complicationValueText(97, 3), "97");
    return true;
}

// The Value font (CLAUDE.md, Fonts) only has the glyphs 0-9 , . : % ° h -;
// every field and readout value must stay inside that set.
(:test)
function formattedValuesUseOnlyValueFontGlyphs(logger as Logger) as Boolean {
    var samples = [
        ApexFormat.thousands(1005007), ApexFormat.thousands(-1846),
        ApexFormat.clockText(19, 12), ApexFormat.recoveryText(14),
        ApexFormat.percentText(68), ApexFormat.distanceText(640000, false),
        ApexFormat.altitudeText(-12, false), ApexFormat.temperatureText(-5.6f, false),
        ApexFormat.numberText(null), ApexFormat.twoDigits(7)
    ];
    for (var i = 0; i < samples.size(); i++) {
        Test.assertMessage(ApexTestUtil.onlyGlyphs(samples[i], ApexTestUtil.VALUE_GLYPHS),
            "'" + samples[i] + "' has a glyph outside the Value font");
    }
    return true;
}
