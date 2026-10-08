import Toybox.Lang;
import Toybox.Math;

// Pure text formatting for the face, kept free of Dc/sensor access so it can be unit tested.
module ApexFormat {

    const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    // "MON 28 SEP": weekday, day without padding, month. dayOfWeek is Gregorian's
    // 1 = Sunday .. 7 = Saturday, month is 1 .. 12.
    function dateText(dayOfWeek as Number, day as Number, month as Number) as String {
        return DAYS[dayOfWeek - 1] + " " + day + " " + MONTHS[month - 1];
    }

    // Zero-padded two-digit value for hours (24 h) and minutes.
    function twoDigits(value as Number) as String {
        return value.format("%02d");
    }

    // "07:04"
    function clockText(hour as Number, minute as Number) as String {
        return twoDigits(hour) + ":" + twoDigits(minute);
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
        return value != null ? value.toString() : ApexMetrics.NO_VALUE;
    }

    // "8,214", or "--" without a reading.
    function thousandsText(value as Number or Null) as String {
        return value != null ? thousands(value) : ApexMetrics.NO_VALUE;
    }

    // "14h"
    function recoveryText(hours as Number or Null) as String {
        return hours != null ? hours + "h" : ApexMetrics.NO_VALUE;
    }

    // "68%"; fractional percentages are truncated.
    function percentText(value as Numeric or Null) as String {
        return value != null ? value.toNumber() + "%" : ApexMetrics.NO_VALUE;
    }

    // Distance in cm as km (or miles when statute), one decimal: "6.4".
    function distanceText(cm as Number or Null, statute as Boolean) as String {
        if (cm == null) {
            return ApexMetrics.NO_VALUE;
        }
        return (cm.toFloat() / (statute ? 160934.4f : 100000.0f)).format("%.1f");
    }

    // Altitude in metres as whole metres (or feet when statute): "312".
    function altitudeText(metres as Numeric or Null, statute as Boolean) as String {
        if (metres == null) {
            return ApexMetrics.NO_VALUE;
        }
        var value = statute ? metres * 3.28084f : metres;
        return value.toNumber().toString();
    }

    // Temperature in °C, rounded, converted to °F when statute: "17°".
    function temperatureText(celsius as Numeric or Null, statute as Boolean) as String {
        if (celsius == null) {
            return ApexMetrics.NO_VALUE;
        }
        var c = celsius.toFloat();
        var value = statute ? c * 9 / 5 + 32 : c;
        return Math.round(value).toNumber() + "°";
    }

    // Value of a system data field: whole floats lose their decimals, others
    // keep one; a String unit is appended.
    function complicationValueText(value as Numeric or String or Null, unit as Object or Null) as String {
        if (value == null) {
            return ApexMetrics.NO_VALUE;
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
