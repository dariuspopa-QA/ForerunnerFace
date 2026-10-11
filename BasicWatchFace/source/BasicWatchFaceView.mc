import Toybox.Application;
import Toybox.Graphics;
using Toybox.Time.Gregorian;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.ActivityMonitor;

class BasicWatchFaceView extends WatchUi.WatchFace {

    // Always-on (low power) colors: dimmed time and date only
    private const C_AOD = 0x9A9A9F;
    private const C_AOD_DATE = 0x5A5A5E;

    private var _awake = true;
    private var _aodFont = null;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    // Update the view
 function onUpdate(dc) {
    // Wrist down on an AMOLED screen: switch to the always-on face
    var settings = System.getDeviceSettings();
    if (!_awake && (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection) {
        drawAod(dc);
        return;
    }

    // 1. Gather Time and Date
    var timeString = timeText();
    var dateString = dateText();

    // 2. Gather Stats (Battery & Steps)
    var battery = System.getSystemStats().battery.toNumber();
    var actInfo = ActivityMonitor.getInfo();
    var steps = (actInfo.steps != null) ? actInfo.steps : 0;
    var stepGoal = (actInfo.stepGoal != null && actInfo.stepGoal > 0) ? actInfo.stepGoal : 5000;

    var statsString = Lang.format("$1$%   |   $2$", [battery, steps]);

    // 3. Update the XML Layout Elements
    (View.findDrawableById("TimeLabel") as WatchUi.Text).setText(timeString);
    (View.findDrawableById("DateLabel") as WatchUi.Text).setText(dateString);
    (View.findDrawableById("StatsLabel") as WatchUi.Text).setText(statsString);

    // 4. Draw the base layout (Background and Text)
    View.onUpdate(dc);

    // 5. Draw the Continuous Progress Arc on top
    var centerX = dc.getWidth() / 2;
    var centerY = dc.getHeight() / 2;
    var radius = centerX - 6; // 6 pixels from the outer edge

    // Draw the dark track for the arc
    dc.setPenWidth(6);
    dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
    dc.drawCircle(centerX, centerY, radius);

    // Calculate and draw the orange progress arc
    var progress = steps.toFloat() / stepGoal.toFloat();
    dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
    
    if (progress >= 1.0) {
        // Goal met: draw a full circle
        dc.drawCircle(centerX, centerY, radius);
    } else if (progress > 0.0) {
        // Calculate degrees (90 is 12 o'clock, drawing clockwise)
        var endDegree = (90 - (progress * 360)).toNumber();
        if (endDegree < 0) { 
            endDegree += 360; 
        }
        dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 90, endDegree);
    }
}

    // Always-on (low power): AMOLED rules - keep lit pixels low and move the
    // content every minute. Only the time (light weight, gray) and the date;
    // no stats line and no ring.
    private function drawAod(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var r = w / 2.0;
        // FaceCore burn-in drift (design px of the 454 screen, scaled to this one)
        var s = FaceKit.aodShift(System.getClockTime().min);
        var dx = s[0] * r / FaceKit.C;
        var dy = s[1] * r / FaceKit.C;

        if (_aodFont == null) {
            // Same height as the awake time, but a lighter weight where the device has one
            _aodFont = Graphics.getVectorFont({
                :face => ["RobotoCondensedLight", "RobotoCondensedRegular", "RobotoRegular"],
                :size => dc.getFontHeight(Graphics.FONT_NUMBER_HOT)
            });
            if (_aodFont == null) {
                _aodFont = Graphics.FONT_NUMBER_HOT;
            }
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(C_AOD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + dx, h / 2 + dy, _aodFont, timeText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(C_AOD_DATE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + dx, h * 0.22 + dy, Graphics.FONT_SMALL, dateText(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function timeText() {
        var clockTime = System.getClockTime();
        return Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
    }

    private function dateText() {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Lang.format("$1$ $2$", [info.day_of_week.toUpper(), info.day]);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        _awake = true;
        WatchUi.requestUpdate();
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        _awake = false;
        WatchUi.requestUpdate();
    }

}
