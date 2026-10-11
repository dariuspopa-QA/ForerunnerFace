import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Tests against the simulator's live sensor data: every metric must render
// something sensible (a value or "--") whatever the simulator returns.
// Use Simulation > Activity Data / Complications to vary the inputs.

(:test)
function everyFieldRendersAValueOrNoValue(logger as Logger) as Boolean {
    var data = new ApexData();
    var clock = System.getClockTime();
    data.refresh(clock);
    for (var id = ApexMetrics.F_HR; id <= ApexMetrics.F_EMPTY; id++) {
        var value = data.fieldValue(id, clock, true);
        logger.debug(ApexMetrics.fieldLabel(id) + " = " + value);
        Test.assertMessage(value.length() > 0, "field " + id + " is empty");
        Test.assertMessage(ApexTestUtil.onlyGlyphs(value, ApexTestUtil.VALUE_GLYPHS),
            "field " + id + " value '" + value + "' has a glyph outside the Value font");
    }
    return true;
}

(:test)
function hiddenEmptyAndUnknownFieldsShowNoValue(logger as Logger) as Boolean {
    var data = new ApexData();
    var clock = System.getClockTime();
    data.refresh(clock);
    ApexTestUtil.assertEqual(data.fieldValue(ApexMetrics.F_READY, clock, true), "--");
    ApexTestUtil.assertEqual(data.fieldValue(ApexMetrics.F_EMPTY, clock, true), "--");
    ApexTestUtil.assertEqual(data.fieldValue(99, clock, true), "--");
    return true;
}

(:test)
function secondsFieldOnlyWhileAwake(logger as Logger) as Boolean {
    var data = new ApexData();
    var clock = System.getClockTime();
    data.refresh(clock);
    ApexTestUtil.assertEqual(data.fieldValue(ApexMetrics.F_SEC, clock, true), ApexFormat.twoDigits(clock.sec));
    ApexTestUtil.assertEqual(data.fieldValue(ApexMetrics.F_SEC, clock, false), "--");
    return true;
}

(:test)
function batteryFieldMatchesSystemStats(logger as Logger) as Boolean {
    var data = new ApexData();
    var clock = System.getClockTime();
    data.refresh(clock);
    var expected = System.getSystemStats().battery.toNumber() + "%";
    ApexTestUtil.assertEqual(data.fieldValue(ApexMetrics.F_BATTERY, clock, true), expected);
    ApexTestUtil.assertEqual(data.arcReadout(ApexMetrics.A_BATTERY), expected);
    return true;
}

(:test)
function notificationsFieldMatchesDeviceSettings(logger as Logger) as Boolean {
    var data = new ApexData();
    var clock = System.getClockTime();
    data.refresh(clock);
    ApexTestUtil.assertEqual(data.fieldValue(ApexMetrics.F_NOTIFS, clock, true),
        System.getDeviceSettings().notificationCount.toString());
    return true;
}

// Cached readings (history, weather, sun times) don't change within a minute.
(:test)
function fieldValuesAreStableWithinAMinute(logger as Logger) as Boolean {
    var data = new ApexData();
    var clock = System.getClockTime();
    data.refresh(clock);
    var ids = [ApexMetrics.F_STEPS, ApexMetrics.F_BODY_BATTERY, ApexMetrics.F_STRESS,
        ApexMetrics.F_SUNRISE, ApexMetrics.F_SUNSET, ApexMetrics.F_TEMP];
    var first = [] as Array<String>;
    for (var i = 0; i < ids.size(); i++) {
        first.add(data.fieldValue(ids[i], clock, true));
    }
    data.refresh(clock);
    for (var i = 0; i < ids.size(); i++) {
        ApexTestUtil.assertEqual(data.fieldValue(ids[i], clock, true), first[i]);
    }
    return true;
}

(:test)
function everyArcFractionIsNullOrWithinZeroOne(logger as Logger) as Boolean {
    var data = new ApexData();
    data.refresh(System.getClockTime());
    for (var id = ApexMetrics.A_BODY_BATTERY; id <= ApexMetrics.A_OFF; id++) {
        var f = data.arcFraction(id);
        var readout = data.arcReadout(id);
        logger.debug(ApexMetrics.arcLabel(id) + " = " + f + " / " + readout);
        if (f != null) {
            Test.assertMessage(f >= 0.0f && f <= 1.0f, "arc " + id + " fraction " + f);
        }
        Test.assertMessage(readout.length() > 0, "arc " + id + " readout is empty");
        Test.assertMessage(ApexTestUtil.onlyGlyphs(readout, ApexTestUtil.VALUE_GLYPHS),
            "arc " + id + " readout '" + readout + "'");
    }
    return true;
}

(:test)
function hiddenAndOffArcsHaveNoReading(logger as Logger) as Boolean {
    var data = new ApexData();
    data.refresh(System.getClockTime());
    ApexTestUtil.assertEqual(data.arcFraction(ApexMetrics.A_READINESS), null);
    ApexTestUtil.assertEqual(data.arcReadout(ApexMetrics.A_READINESS), "--");
    ApexTestUtil.assertEqual(data.arcFraction(ApexMetrics.A_OFF), null);
    ApexTestUtil.assertEqual(data.arcReadout(ApexMetrics.A_OFF), "--");
    return true;
}

(:test)
function batteryArcMatchesSystemStats(logger as Logger) as Boolean {
    var data = new ApexData();
    data.refresh(System.getClockTime());
    ApexTestUtil.assertNear(data.arcFraction(ApexMetrics.A_BATTERY) as Float,
        System.getSystemStats().battery / 100.0f, 0.0001f, "battery fraction");
    return true;
}

// Body battery and stress arcs read the same source as their fields; the
// step goal readout is the fill percentage.
(:test)
function arcReadoutsAgreeWithFields(logger as Logger) as Boolean {
    var data = new ApexData();
    var clock = System.getClockTime();
    data.refresh(clock);
    ApexTestUtil.assertEqual(data.arcReadout(ApexMetrics.A_BODY_BATTERY),
        data.fieldValue(ApexMetrics.F_BODY_BATTERY, clock, true));
    ApexTestUtil.assertEqual(data.arcReadout(ApexMetrics.A_STRESS),
        data.fieldValue(ApexMetrics.F_STRESS, clock, true));
    var f = data.arcFraction(ApexMetrics.A_STEP_GOAL);
    ApexTestUtil.assertEqual(data.arcReadout(ApexMetrics.A_STEP_GOAL), f != null ? (f * 100).toNumber() + "%" : "--");
    return true;
}
