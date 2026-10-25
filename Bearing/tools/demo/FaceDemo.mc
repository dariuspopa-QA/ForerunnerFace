import Toybox.Lang;
import Toybox.System;
import Toybox.Time.Gregorian;

// Demo build (demo.jungle): the design's time (10:47) and readings (78 % battery, 8,560 steps).
module FaceDemo {
    const FORCE_24H = true;
    // Draw the Always-On screen even while awake (screenshots of the low-power look)
    const FORCE_AOD = false;
    // Watch battery shown (store shots set it with -Demo "BATTERY=45")
    const BATTERY = 78;

    function apply(data as FaceData) as Void {
        data.steps = 8560;
        data.stepGoal = 10000;
        data.stress = 28;
        data.bodyBattery = 64;
        data.hrOverride = 61;
    }

    function time(clock as System.ClockTime, now as Gregorian.Info) as Void {
        clock.hour = 10;
        clock.min = 47;
        clock.sec = 12;
        now.hour = 10;
        now.min = 47;
        now.day = 25;
        now.month = 10;
        now.year = 2026;
        now.day_of_week = 1;
    }

    function battery(real as Number) as Number {
        return BATTERY;
    }
}
