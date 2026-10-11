import Toybox.Lang;
import Toybox.System;
import Toybox.Time.Gregorian;

// Live build: real time and readings (tools/demo/FaceDemo.mc replaces this in demo.jungle).
module FaceDemo {
    const FORCE_24H = false;
    // Draw the Always-On screen even while awake (screenshots of the low-power look)
    const FORCE_AOD = false;

    function apply(data as FaceData) as Void {
    }

    function time(clock as System.ClockTime, now as Gregorian.Info) as Void {
    }

    function battery(real as Number) as Number {
        return real;
    }
}
