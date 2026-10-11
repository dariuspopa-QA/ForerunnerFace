import Toybox.Lang;
import Toybox.System;
import Toybox.Time.Gregorian;

// Demo build (demo.jungle): the mockup's time (Sat 11 Oct 10:08:42) and readings.
module FaceDemo {
    const FORCE_24H = true;
    // Draw the Always-On screen even while awake (screenshots of the low-power look)
    const FORCE_AOD = false;

    function apply(data as FaceData) as Void {
        data.steps = 8412;
        data.stepGoal = 10000;
        data.stress = 34;
        data.bodyBattery = 61;
        data.hrOverride = 72;
        data.hrHoursOverride = [68, 70, 74, 79, 83, 80, 76, 72, 71, 75, 88, 96, 101, 94, 86, 80, 77, 74, 72, 73, 75, 72, 70, 72];
    }

    function time(clock as System.ClockTime, now as Gregorian.Info) as Void {
        clock.hour = 10;
        clock.min = 8;
        clock.sec = 42;
        now.hour = 10;
        now.min = 8;
        now.day = 11;
        now.month = 10;
        now.year = 2026;
        now.day_of_week = 7;
    }

    function battery(real as Number) as Number {
        return 84;
    }
}
