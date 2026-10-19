import Toybox.Lang;
import Toybox.System;
import Toybox.Time.Gregorian;

// Demo build (demo.jungle): the mockup's time (Sat 10 Oct 16:08) and readings.
module FaceDemo {
    const FORCE_24H = true;
    // Draw the Always-On screen even while awake (screenshots of the low-power look)
    const FORCE_AOD = false;

    function apply(data as FaceData) as Void {
        data.steps = 7412;
        data.stepGoal = 10000;
        data.floors = 6;
        data.floorsGoal = 15;
        data.intensity = 83;
        data.intensityGoal = 150;
        data.stress = 24;
        data.recoveryHours = 26;
        data.temperature = 14;
        data.condition = 1;
        data.sunrise = 7.2167f;
        data.sunset = 18.3333f;
        data.sleepTime = 23.1667f;
        data.wakeTime = 6.75f;
        data.hrOverride = 62;
        data.eventOverride = "18:30";
        data.sleepOverride = 82;
        data.respirationOverride = 14;
        data.bodyBattery = 68;
    }

    function time(clock as System.ClockTime, now as Gregorian.Info) as Void {
        clock.hour = 16;
        clock.min = 8;
        clock.sec = 42;
        now.hour = 16;
        now.min = 8;
        now.day = 10;
        now.month = 10;
        now.year = 2026;
        now.day_of_week = 7;
    }
}
