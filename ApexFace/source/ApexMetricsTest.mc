import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Unit tests for the metric tables, settings validation and editor mapping.

// ---- Settings validation ----------------------------------------------

(:test)
function validFieldKeepsEveryListedField(logger as Logger) as Boolean {
    for (var id = ApexMetrics.F_HR; id <= ApexMetrics.F_SOLAR; id++) {
        if (id != ApexMetrics.F_READY) {
            ApexTestUtil.assertEqual(ApexMetrics.validField(id), id);
        }
    }
    return true;
}

(:test)
function validFieldEmptiesHiddenAndUnknownIds(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.validField(ApexMetrics.F_READY), ApexMetrics.F_EMPTY);
    ApexTestUtil.assertEqual(ApexMetrics.validField(-1), ApexMetrics.F_EMPTY);
    ApexTestUtil.assertEqual(ApexMetrics.validField(ApexMetrics.F_SOLAR + 1), ApexMetrics.F_EMPTY);
    ApexTestUtil.assertEqual(ApexMetrics.validField(0xC8FF2E), ApexMetrics.F_EMPTY);
    return true;
}

(:test)
function validArcKeepsEveryListedArc(logger as Logger) as Boolean {
    for (var id = ApexMetrics.A_BODY_BATTERY; id <= ApexMetrics.A_OFF; id++) {
        if (id != ApexMetrics.A_READINESS) {
            ApexTestUtil.assertEqual(ApexMetrics.validArc(id), id);
        }
    }
    return true;
}

(:test)
function validArcTurnsHiddenAndUnknownIdsOff(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.validArc(ApexMetrics.A_READINESS), ApexMetrics.A_OFF);
    ApexTestUtil.assertEqual(ApexMetrics.validArc(-1), ApexMetrics.A_OFF);
    ApexTestUtil.assertEqual(ApexMetrics.validArc(7), ApexMetrics.A_OFF);
    return true;
}

// ---- Fractions --------------------------------------------------------

(:test)
function clampFractionLimitsToZeroOne(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.clampFraction(-0.2f), 0.0f);
    ApexTestUtil.assertEqual(ApexMetrics.clampFraction(0.0f), 0.0f);
    ApexTestUtil.assertEqual(ApexMetrics.clampFraction(0.42f), 0.42f);
    ApexTestUtil.assertEqual(ApexMetrics.clampFraction(1.0f), 1.0f);
    ApexTestUtil.assertEqual(ApexMetrics.clampFraction(1.7f), 1.0f);
    return true;
}

(:test)
function percentFractionScalesAndClamps(logger as Logger) as Boolean {
    ApexTestUtil.assertNear(ApexMetrics.percentFraction(72) as Float, 0.72f, 0.0001f, "72");
    ApexTestUtil.assertEqual(ApexMetrics.percentFraction(0), 0.0f);
    ApexTestUtil.assertEqual(ApexMetrics.percentFraction(100), 1.0f);
    ApexTestUtil.assertEqual(ApexMetrics.percentFraction(150), 1.0f);
    ApexTestUtil.assertEqual(ApexMetrics.percentFraction(-5), 0.0f);
    ApexTestUtil.assertEqual(ApexMetrics.percentFraction(null), null);
    return true;
}

(:test)
function goalFractionCapsAtGoal(logger as Logger) as Boolean {
    ApexTestUtil.assertNear(ApexMetrics.goalFraction(8214, 10000) as Float, 0.8214f, 0.0001f, "steps");
    ApexTestUtil.assertEqual(ApexMetrics.goalFraction(12000, 10000), 1.0f);
    ApexTestUtil.assertEqual(ApexMetrics.goalFraction(0, 150), 0.0f);
    return true;
}

(:test)
function goalFractionNeedsReadingAndPositiveGoal(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.goalFraction(null, 10000), null);
    ApexTestUtil.assertEqual(ApexMetrics.goalFraction(500, null), null);
    ApexTestUtil.assertEqual(ApexMetrics.goalFraction(500, 0), null);
    ApexTestUtil.assertEqual(ApexMetrics.goalFraction(500, -1), null);
    return true;
}

// ---- Labels -----------------------------------------------------------

(:test)
function fieldLabelsMatchTheMetricTable(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_HR), "HR");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_STEPS), "STEPS");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_CALORIES), "KCAL");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_FLOORS), "FLOORS");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_STRESS), "STRESS");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_BODY_BATTERY), "BODY BATT");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_RECOVERY), "RECOVERY");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_SUNRISE), "SUNRISE");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_SUNSET), "SUNSET");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_TEMP), "TEMP");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_BATTERY), "BATTERY");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_NOTIFS), "NOTIFS");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_SEC), "SEC");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_EMPTY), "");
    return true;
}

(:test)
function unitFieldLabelsFollowDeviceUnits(logger as Logger) as Boolean {
    var settings = System.getDeviceSettings();
    var statuteDistance = settings.distanceUnits == System.UNIT_STATUTE;
    var statuteElevation = settings.elevationUnits == System.UNIT_STATUTE;
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_DISTANCE), statuteDistance ? "MI" : "KM");
    ApexTestUtil.assertEqual(ApexMetrics.fieldLabel(ApexMetrics.F_ALTITUDE), statuteElevation ? "ALT FT" : "ALT M");
    return true;
}

(:test)
function arcLabelsMatchTheArcTable(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.arcLabel(ApexMetrics.A_BODY_BATTERY), "BODY BATT");
    ApexTestUtil.assertEqual(ApexMetrics.arcLabel(ApexMetrics.A_STEP_GOAL), "STEP GOAL");
    ApexTestUtil.assertEqual(ApexMetrics.arcLabel(ApexMetrics.A_BATTERY), "BATTERY");
    ApexTestUtil.assertEqual(ApexMetrics.arcLabel(ApexMetrics.A_STRESS), "STRESS");
    ApexTestUtil.assertEqual(ApexMetrics.arcLabel(ApexMetrics.A_INTENSITY), "INTENSITY MIN");
    ApexTestUtil.assertEqual(ApexMetrics.arcLabel(ApexMetrics.A_OFF), "");
    return true;
}

// Field labels (Mono16) use A-Z, digits and space; arc labels (Mono14) A-Z and space.
(:test)
function labelsUseOnlyMonoFontGlyphs(logger as Logger) as Boolean {
    for (var id = ApexMetrics.F_HR; id <= ApexMetrics.F_SOLAR; id++) {
        var label = ApexMetrics.fieldLabel(id);
        Test.assertMessage(ApexTestUtil.onlyGlyphs(label, ApexTestUtil.FIELD_LABEL_GLYPHS), "field label '" + label + "'");
    }
    for (var id = ApexMetrics.A_BODY_BATTERY; id <= ApexMetrics.A_OFF; id++) {
        var label = ApexMetrics.arcLabel(id);
        Test.assertMessage(ApexTestUtil.onlyGlyphs(label, ApexTestUtil.LABEL_GLYPHS), "arc label '" + label + "'");
    }
    return true;
}

// Mono22 only has A-Z, 0-9, space and "-".
(:test)
function everyDateUsesOnlyDateFontGlyphs(logger as Logger) as Boolean {
    for (var format = FaceFormat.DATE_NAMED; format <= FaceFormat.DATE_MDY; format++) {
        for (var dow = 1; dow <= 7; dow++) {
            for (var month = 1; month <= 12; month++) {
                var text = FaceFormat.dateText(dow, 31, month, 2026, format);
                Test.assertMessage(ApexTestUtil.onlyGlyphs(text, ApexTestUtil.DATE_GLYPHS), "date '" + text + "'");
            }
        }
    }
    return true;
}

// ---- Watch face editor mapping ----------------------------------------

(:test)
function fieldForComplicationMapsOwnSources(logger as Logger) as Boolean {
    var pairs = [
        [Complications.COMPLICATION_TYPE_HEART_RATE, ApexMetrics.F_HR],
        [Complications.COMPLICATION_TYPE_STEPS, ApexMetrics.F_STEPS],
        [Complications.COMPLICATION_TYPE_CALORIES, ApexMetrics.F_CALORIES],
        [Complications.COMPLICATION_TYPE_FLOORS_CLIMBED, ApexMetrics.F_FLOORS],
        [Complications.COMPLICATION_TYPE_STRESS, ApexMetrics.F_STRESS],
        [Complications.COMPLICATION_TYPE_BODY_BATTERY, ApexMetrics.F_BODY_BATTERY],
        [Complications.COMPLICATION_TYPE_RECOVERY_TIME, ApexMetrics.F_RECOVERY],
        [Complications.COMPLICATION_TYPE_SUNRISE, ApexMetrics.F_SUNRISE],
        [Complications.COMPLICATION_TYPE_SUNSET, ApexMetrics.F_SUNSET],
        [Complications.COMPLICATION_TYPE_ALTITUDE, ApexMetrics.F_ALTITUDE],
        [Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE, ApexMetrics.F_TEMP],
        [Complications.COMPLICATION_TYPE_BATTERY, ApexMetrics.F_BATTERY],
        [Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT, ApexMetrics.F_NOTIFS],
        [Complications.COMPLICATION_TYPE_INTENSITY_MINUTES, ApexMetrics.F_INTENSITY],
        [Complications.COMPLICATION_TYPE_PULSE_OX, ApexMetrics.F_PULSE_OX],
        [Complications.COMPLICATION_TYPE_RESPIRATION_RATE, ApexMetrics.F_RESPIRATION],
        [Complications.COMPLICATION_TYPE_VO2MAX_RUN, ApexMetrics.F_VO2_RUN],
        [Complications.COMPLICATION_TYPE_VO2MAX_BIKE, ApexMetrics.F_VO2_BIKE],
        [Complications.COMPLICATION_TYPE_SEA_LEVEL_PRESSURE, ApexMetrics.F_PRESSURE],
        [Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE, ApexMetrics.F_RUN_WEEK],
        [Complications.COMPLICATION_TYPE_SOLAR_INPUT, ApexMetrics.F_SOLAR]
    ];
    for (var i = 0; i < pairs.size(); i++) {
        ApexTestUtil.assertEqual(ApexMetrics.fieldForComplication(pairs[i][0] as Complications.Type), pairs[i][1]);
    }
    return true;
}

// Types the face has no field for fall through to the system value (null here).
(:test)
function fieldForComplicationLeavesOtherTypesToTheSystem(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.fieldForComplication(null), null);
    ApexTestUtil.assertEqual(ApexMetrics.fieldForComplication(Complications.COMPLICATION_TYPE_CURRENT_WEATHER), null);
    return true;
}

// The system data fields (phone settings 17-25) read the type the editor offers;
// the editor maps each type back to the same field, so both lists agree.
(:test)
function systemDataFieldsRoundTripThroughTheEditorType(logger as Logger) as Boolean {
    for (var id = ApexMetrics.F_PULSE_OX; id <= ApexMetrics.F_SOLAR; id++) {
        var type = ApexMetrics.complicationType(id);
        if (type == null) {
            Test.assertMessage(id == ApexMetrics.F_SLEEP, "field " + id + " has no data type");
            continue;
        }
        ApexTestUtil.assertEqual(ApexMetrics.fieldForComplication(type), id);
    }
    for (var id = ApexMetrics.F_HR; id <= ApexMetrics.F_INTENSITY; id++) {
        ApexTestUtil.assertEqual(ApexMetrics.complicationType(id), null);
    }
    return true;
}

(:test)
function arcForComplicationMapsEveryArcSlotType(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.arcForComplication(Complications.COMPLICATION_TYPE_BODY_BATTERY), ApexMetrics.A_BODY_BATTERY);
    ApexTestUtil.assertEqual(ApexMetrics.arcForComplication(Complications.COMPLICATION_TYPE_STEPS), ApexMetrics.A_STEP_GOAL);
    ApexTestUtil.assertEqual(ApexMetrics.arcForComplication(Complications.COMPLICATION_TYPE_BATTERY), ApexMetrics.A_BATTERY);
    ApexTestUtil.assertEqual(ApexMetrics.arcForComplication(Complications.COMPLICATION_TYPE_STRESS), ApexMetrics.A_STRESS);
    ApexTestUtil.assertEqual(ApexMetrics.arcForComplication(Complications.COMPLICATION_TYPE_INTENSITY_MINUTES), ApexMetrics.A_INTENSITY);
    return true;
}

(:test)
function arcForComplicationIgnoresOtherTypes(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexMetrics.arcForComplication(null), null);
    ApexTestUtil.assertEqual(ApexMetrics.arcForComplication(Complications.COMPLICATION_TYPE_HEART_RATE), null);
    ApexTestUtil.assertEqual(ApexMetrics.arcForComplication(Complications.COMPLICATION_TYPE_SUNSET), null);
    return true;
}

(:test)
function complicationTextAlwaysReturnsValueAndLabel(logger as Logger) as Boolean {
    var types = [
        Complications.COMPLICATION_TYPE_PULSE_OX,
        Complications.COMPLICATION_TYPE_VO2MAX_RUN,
        Complications.COMPLICATION_TYPE_SEA_LEVEL_PRESSURE
    ];
    for (var i = 0; i < types.size(); i++) {
        var result = ApexMetrics.complicationText(new Complications.Id(types[i] as Complications.Type));
        ApexTestUtil.assertEqual(result.size(), 2);
        Test.assert(result[0].length() > 0);
        ApexTestUtil.assertEqual(result[1], result[1].toUpper());
    }
    return true;
}

// Every shared FaceFormat text must be drawable with ApexFace's Value font.
(:test)
function formattedValuesUseOnlyValueFontGlyphs(logger as Logger) as Boolean {
    var samples = [
        FaceFormat.thousands(1005007), FaceFormat.thousands(-1846),
        FaceFormat.clockText(19, 12, true), FaceFormat.recoveryText(14),
        FaceFormat.percentText(68), FaceFormat.distanceText(640000, false),
        FaceFormat.altitudeText(-12, false), FaceFormat.temperatureText(-5.6f, false),
        FaceFormat.numberText(null), FaceFormat.twoDigits(7)
    ];
    for (var i = 0; i < samples.size(); i++) {
        Test.assertMessage(ApexTestUtil.onlyGlyphs(samples[i], ApexTestUtil.VALUE_GLYPHS),
            "'" + samples[i] + "' has a glyph outside the Value font");
    }
    return true;
}
