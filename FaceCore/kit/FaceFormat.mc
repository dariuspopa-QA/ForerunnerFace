import Toybox.Lang;
import Toybox.Math;

// Pure text formatting shared by every face (from ApexFace), kept free of Dc/sensor access so
// it can be unit tested (FaceCore/test/FaceFormatTest.mc).
module FaceFormat {

    // Shown for a value the watch has no reading for
    const NO_VALUE = "--";

    const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    // DateFormat setting: follow the watch, "MON 28 SEP", "MON 28-09-2026", "MON 09-28-2026"
    enum { DATE_WATCH = 0, DATE_NAMED = 1, DATE_DMY = 2, DATE_MDY = 3 }

    // The date format to draw for the DateFormat setting. Connect IQ doesn't expose the
    // watch's date order, so "watch" infers it from the distance units: miles means
    // US-style month first, km day first.
    function dateFormat(setting as Number, statute as Boolean) as Number {
        if (setting == DATE_NAMED || setting == DATE_DMY || setting == DATE_MDY) {
            return setting;
        }
        return statute ? DATE_MDY : DATE_DMY;
    }

    // Weekday followed by the date in the given (resolved) format's order. dayOfWeek is
    // Gregorian's 1 = Sunday .. 7 = Saturday, month is 1 .. 12. The named format keeps
    // the day unpadded ("WED 9 JUL"), the numeric ones pad day and month ("WED 09-07-2026").
    function dateText(dayOfWeek as Number, day as Number, month as Number, year as Number, format as Number) as String {
        var weekday = DAYS[dayOfWeek - 1] + " ";
        if (format == DATE_DMY) {
            return weekday + twoDigits(day) + "-" + twoDigits(month) + "-" + year;
        }
        if (format == DATE_MDY) {
            return weekday + twoDigits(month) + "-" + twoDigits(day) + "-" + year;
        }
        return weekday + day + " " + MONTHS[month - 1];
    }

    // Zero-padded two-digit value for hours (24 h) and minutes.
    function twoDigits(value as Number) as String {
        return value.format("%02d");
    }

    // Hour of a 0 .. 23 clock: zero-padded in 24 h ("07"), 1 .. 12 unpadded in 12 h ("7").
    function hourText(hour as Number, twelve as Boolean) as String {
        if (!twelve) {
            return twoDigits(hour);
        }
        var h = hour % 12;
        return (h == 0 ? 12 : h).toString();
    }

    // "07:04", or "7:04" in 12 h
    function clockText(hour as Number, minute as Number, twelve as Boolean) as String {
        return hourText(hour, twelve) + ":" + twoDigits(minute);
    }

    // "8,214"; negative values keep their sign.
    function thousands(value as Number) as String {
        var sign = value < 0 ? "-" : "";
        var rest = value.abs();
        var groups = "";
        while (rest >= 1000) {
            groups = "," + (rest % 1000).format("%03d") + groups;
            rest = rest / 1000;
        }
        return sign + rest.toString() + groups;
    }

    // "58", or "--" without a reading.
    function numberText(value as Number or Null) as String {
        return value != null ? value.toString() : NO_VALUE;
    }

    // "8,214", or "--" without a reading.
    function thousandsText(value as Number or Null) as String {
        return value != null ? thousands(value) : NO_VALUE;
    }

    // "14h"
    function recoveryText(hours as Number or Null) as String {
        return hours != null ? hours + "h" : NO_VALUE;
    }

    // "68%"; fractional percentages are truncated.
    function percentText(value as Numeric or Null) as String {
        return value != null ? value.toNumber() + "%" : NO_VALUE;
    }

    // Distance in cm as km (or miles when statute), one decimal: "6.4".
    function distanceText(cm as Number or Null, statute as Boolean) as String {
        if (cm == null) {
            return NO_VALUE;
        }
        return (cm.toFloat() / (statute ? 160934.4f : 100000.0f)).format("%.1f");
    }

    // Altitude in metres as whole metres (or feet when statute): "312".
    function altitudeText(metres as Numeric or Null, statute as Boolean) as String {
        if (metres == null) {
            return NO_VALUE;
        }
        var value = statute ? metres * 3.28084f : metres;
        return value.toNumber().toString();
    }

    // Temperature in °C, rounded, converted to °F when statute: "17°".
    function temperatureText(celsius as Numeric or Null, statute as Boolean) as String {
        if (celsius == null) {
            return NO_VALUE;
        }
        var c = celsius.toFloat();
        var value = statute ? c * 9 / 5 + 32 : c;
        return Math.round(value).toNumber() + "°";
    }

    // Value of a system data field: whole floats lose their decimals, others
    // keep one; a String unit is appended.
    function complicationValueText(value as Numeric or String or Null, unit as Object or Null) as String {
        if (value == null) {
            return NO_VALUE;
        }
        var text;
        if (value instanceof Float || value instanceof Double) {
            var n = value.toNumber();
            text = (value == n) ? n.toString() : value.format("%.1f");
        } else {
            text = value.toString();
        }
        if (unit instanceof String) {
            text += unit as String;
        }
        return text;
    }
}
