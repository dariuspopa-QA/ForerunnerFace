import Toybox.Lang;
import Toybox.Test;

// About 0.0003° of latitude is 33 m.
module TrackFixture {
    const STEP = 0.0003;
}

(:test)
function trackStandingStillKeepsOnePoint(logger as Logger) as Boolean {
    var t = new Track();
    for (var i = 0; i < 20; i++) {
        t.onFix(48.2, 16.37, true);
    }
    return t.lats.size() == 1;
}

(:test)
function trackKeepsMovesOnlyWhileRecording(logger as Logger) as Boolean {
    var t = new Track();
    for (var i = 0; i < 5; i++) {
        t.onFix(48.2 + i * TrackFixture.STEP, 16.37, false);
    }
    var before = t.lats.size();
    for (var i = 0; i < 5; i++) {
        t.onFix(48.21 + i * TrackFixture.STEP, 16.37, true);
    }
    return before == 0 && t.lats.size() == 5 && t.curLat != null;
}

(:test)
function trackThinsWhenFull(logger as Logger) as Boolean {
    var t = new Track();
    var last = 0.0;
    for (var i = 0; i < 1200; i++) {
        last = 48.0 + i * TrackFixture.STEP;
        t.onFix(last, 16.37, true);
    }
    // Thinning widens the spacing past the 33 m steps, so the newest fix may be skipped:
    // the kept track ends close to it and the "you are here" dot is exactly on it.
    var n = t.lats.size();
    var gap = Track.distanceM(t.lats[n - 1], 16.37, last.toFloat(), 16.37);
    logger.debug("points " + n + " end gap " + gap.toNumber() + " m");
    return n <= t.MAX_POINTS && n > t.MAX_POINTS / 4 && gap < 200.0 && t.curLat == last.toFloat();
}

(:test)
function trackClearEmpties(logger as Logger) as Boolean {
    var t = new Track();
    t.onFix(48.2, 16.37, true);
    t.onFix(48.21, 16.37, true);
    t.clear();
    return t.lats.size() == 0 && t.lons.size() == 0;
}
