import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// Drawing shared by every page: page dots, recording state and the twist counter.
module Chrome {

    const ACCENT = 0x3FD0FF;
    const REC = 0xFF3B30;
    const DIM = 0x8A8A8A;

    function speedText(mps as Float?) as String {
        if (mps == null) {
            return "--";
        }
        var f = metric() ? 3.6 : 2.23694;
        return (mps * f).format("%.1f");
    }

    function speedUnit() as String {
        return metric() ? "km/h" : "mph";
    }

    function distText(m as Float?) as String {
        if (m == null) {
            return "0.00";
        }
        return (m / (metric() ? 1000.0 : 1609.344)).format("%.2f");
    }

    function distUnit() as String {
        return metric() ? "km" : "mi";
    }

    function timeText(ms as Number?) as String {
        var s = ms == null ? 0 : ms / 1000;
        var h = s / 3600;
        var m = (s / 60) % 60;
        if (h > 0) {
            return h + ":" + m.format("%02d") + ":" + (s % 60).format("%02d");
        }
        return m + ":" + (s % 60).format("%02d");
    }

    function metric() as Boolean {
        return System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
    }

    // Top: REC / PAUSED / START prompt. Bottom: twist counter. Right edge: page dots.
    function draw(dc as Graphics.Dc, ride as Ride, det as TwistDetector, page as Number, pages as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var state = ride.isRecording() ? "REC" : (ride.isOpen() ? "PAUSED" : "START TO RIDE");
        dc.setColor(ride.isRecording() ? REC : ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.08, Graphics.FONT_XTINY, state, Graphics.TEXT_JUSTIFY_CENTER);

        var r = 6;
        var gap = 22;
        var y0 = h / 2 - (pages - 1) * gap / 2;
        for (var i = 0; i < pages; i++) {
            dc.setColor(i == page ? ACCENT : DIM, Graphics.COLOR_TRANSPARENT);
            if (i == page) {
                dc.fillCircle(w - 22, y0 + i * gap, r);
            } else {
                dc.drawCircle(w - 22, y0 + i * gap, r - 2);
            }
        }

        if (showDebug()) {
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.86, Graphics.FONT_XTINY,
                sensorText(det),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // A page that fails to draw shows the error instead of crashing the app, and logs it.
    function drawError(dc as Graphics.Dc, e as Exception) as Void {
        getApp().noteError("draw", e);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var msg = e.getErrorMessage();
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_XTINY,
            "draw error\n" + (msg != null ? msg : "?"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Twist counts, or what went wrong: no motion samples yet, or caught errors.
    function sensorText(det as TwistDetector) as String {
        var app = getApp();
        if (app.sensorErrors > 0) {
            return "error " + app.sensorErrors + " (see log)";
        }
        if (app.sensorBatches == 0) {
            return "no accel data";
        }
        return "twists " + det.twists + "  switches " + det.switches;
    }

    function label(dc as Graphics.Dc, x as Number, y as Number, value as String, unit as String, big as Boolean) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, big ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MILD, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var fh = dc.getFontHeight(big ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MILD);
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + fh / 2, Graphics.FONT_XTINY, unit, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// Redraws once a second while on screen.
class TickingView extends WatchUi.View {

    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:tick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    function tick() as Void {
        WatchUi.requestUpdate();
    }
}

// Page 0: speed, distance, ride time. Page 1: heart rate, climb, average speed, clock.
class StatsPage extends TickingView {

    private var _ride as Ride;
    private var _det as TwistDetector;
    private var _page as Number;
    private var _pages as Number;

    function initialize(ride as Ride, det as TwistDetector, page as Number, pages as Number) {
        TickingView.initialize();
        _ride = ride;
        _det = det;
        _page = page;
        _pages = pages;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        try {
            drawPage(dc);
        } catch (e) {
            Chrome.drawError(dc, e);
        }
    }

    private function drawPage(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var info = Activity.getActivityInfo();

        if (_page == 0) {
            Chrome.label(dc, w / 2, (h * 0.33).toNumber(),
                Chrome.speedText(info != null ? info.currentSpeed : null), Chrome.speedUnit(), true);
            Chrome.label(dc, (w * 0.3).toNumber(), (h * 0.62).toNumber(),
                Chrome.distText(info != null ? info.elapsedDistance : null), Chrome.distUnit(), false);
            Chrome.label(dc, (w * 0.68).toNumber(), (h * 0.62).toNumber(),
                Chrome.timeText(info != null ? info.timerTime : null), "time", false);
        } else {
            var hr = info != null ? info.currentHeartRate : null;
            Chrome.label(dc, w / 2, (h * 0.33).toNumber(), hr == null ? "--" : hr.toString(), "bpm", true);
            var climb = info != null ? info.totalAscent : null;
            Chrome.label(dc, (w * 0.3).toNumber(), (h * 0.62).toNumber(),
                climb == null ? "0" : climb.toNumber().toString(), "m up", false);
            Chrome.label(dc, (w * 0.68).toNumber(), (h * 0.62).toNumber(),
                Chrome.speedText(info != null ? info.averageSpeed : null), "avg " + Chrome.speedUnit(), false);
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            dc.setColor(Chrome.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.15, Graphics.FONT_XTINY,
                now.hour.format("%02d") + ":" + now.min.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
        Chrome.draw(dc, _ride, _det, _page, _pages);
    }
}

// Page 2: the ride's own breadcrumb, north up and scaled to fit, with you as a dot.
// Drawn by the app, not the watch's MapTrackView: on the fr970 that view crashed the app
// with an error that could not be caught.
class MapPage extends TickingView {

    const TRACK = 0x3FD0FF;
    const SCALES_M = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000];
    const SCALES_MI = [0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0];

    private var _ride as Ride;
    private var _det as TwistDetector;
    private var _page as Number;
    private var _pages as Number;

    function initialize(ride as Ride, det as TwistDetector, page as Number, pages as Number) {
        TickingView.initialize();
        _ride = ride;
        _det = det;
        _page = page;
        _pages = pages;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        try {
            drawPage(dc);
        } catch (e) {
            Chrome.drawError(dc, e);
        }
    }

    private function drawPage(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        drawTrack(dc, w, h);

        var info = Activity.getActivityInfo();
        var speed = Chrome.speedText(info != null ? info.currentSpeed : null) + " " + Chrome.speedUnit();
        var pw = dc.getTextWidthInPixels(speed, Graphics.FONT_SMALL) + 24;
        var ph = dc.getFontHeight(Graphics.FONT_SMALL) + 8;
        var py = (h * 0.68).toNumber();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(w / 2 - pw / 2, py, pw, ph, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, py + ph / 2, Graphics.FONT_SMALL, speed,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        Chrome.draw(dc, _ride, _det, _page, _pages);
    }

    // Track and position fitted into a box between the status text and the speed box.
    private function drawTrack(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var track = getApp().track;
        var n = track.lats.size();
        var hasCur = track.curLat != null && track.curLon != null;
        if (n == 0 && !hasCur) {
            dc.setColor(Chrome.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.42, Graphics.FONT_SMALL, "waiting for GPS",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Local metres around the first point (or the current one before the ride starts).
        var lat0 = n > 0 ? track.lats[0] : track.curLat as Float;
        var lon0 = n > 0 ? track.lons[0] : track.curLon as Float;
        var xs = new Array<Float>[n];
        var ys = new Array<Float>[n];
        var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
        for (var i = 0; i < n; i++) {
            xs[i] = Track.eastM(track.lons[i] - lon0, lat0);
            ys[i] = Track.northM(track.lats[i] - lat0);
            minX = xs[i] < minX ? xs[i] : minX;
            maxX = xs[i] > maxX ? xs[i] : maxX;
            minY = ys[i] < minY ? ys[i] : minY;
            maxY = ys[i] > maxY ? ys[i] : maxY;
        }
        var curX = 0.0;
        var curY = 0.0;
        if (hasCur) {
            curX = Track.eastM((track.curLon as Float) - lon0, lat0);
            curY = Track.northM((track.curLat as Float) - lat0);
            minX = curX < minX ? curX : minX;
            maxX = curX > maxX ? curX : maxX;
            minY = curY < minY ? curY : minY;
            maxY = curY > maxY ? curY : maxY;
        }

        // Box: 40% of the width, between the scale bar and the speed box; at least 200 m across.
        var box = w * 0.40;
        var span = maxX - minX > maxY - minY ? maxX - minX : maxY - minY;
        span = span < 200.0 ? 200.0 : span;
        var scale = box / span;   // px per metre
        var cx = w / 2.0;
        var cy = h * 0.47;
        var midX = (minX + maxX) / 2.0;
        var midY = (minY + maxY) / 2.0;

        dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        for (var i = 1; i < n; i++) {
            dc.drawLine(cx + (xs[i - 1] - midX) * scale, cy - (ys[i - 1] - midY) * scale,
                cx + (xs[i] - midX) * scale, cy - (ys[i] - midY) * scale);
        }
        dc.setPenWidth(1);
        if (hasCur) {
            var px = cx + (curX - midX) * scale;
            var py = cy - (curY - midY) * scale;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 9);
            dc.setColor(Chrome.REC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 6);
        }
        drawScale(dc, w, h, scale);
    }

    // Largest round distance that fits in about a fifth of the screen, as a bar with a label.
    private function drawScale(dc as Graphics.Dc, w as Number, h as Number, scale as Float) as Void {
        var metric = Chrome.metric();
        var steps = metric ? SCALES_M : SCALES_MI;
        var unitM = metric ? 1.0 : 1609.344;
        var maxPx = w * 0.22;
        var pick = steps[0].toFloat();
        for (var i = 0; i < steps.size(); i++) {
            if (steps[i].toFloat() * unitM * scale <= maxPx) {
                pick = steps[i].toFloat();
            }
        }
        var len = pick * unitM * scale;
        var label;
        if (metric) {
            label = pick >= 1000.0 ? (pick / 1000.0).format("%d") + " km" : pick.format("%d") + " m";
        } else {
            label = (pick < 1.0 ? pick.format("%.2f") : pick.format("%d")) + " mi";
        }
        var x0 = w / 2.0 - len / 2.0;
        var y = h * 0.25;
        dc.setColor(Chrome.DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(x0, y, x0 + len, y);
        dc.drawLine(x0, y - 5, x0, y + 5);
        dc.drawLine(x0 + len, y - 5, x0 + len, y + 5);
        dc.setPenWidth(1);
        dc.drawText(w / 2, y - 8 - dc.getFontHeight(Graphics.FONT_XTINY) / 2, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
