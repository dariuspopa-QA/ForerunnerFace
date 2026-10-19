import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Synthetic 25 Hz streams: gravity tilted by `deg` around the x axis.
module TwistFixture {
    const PERIOD = 40;

    function tilt(det as TwistDetector, deg as Number, samples as Number) as Number {
        var rad = deg * Math.PI / 180.0;
        var xs = [] as Array<Number>;
        var ys = [] as Array<Number>;
        var zs = [] as Array<Number>;
        for (var i = 0; i < samples; i++) {
            xs.add(0);
            ys.add((1000 * Math.sin(rad)).toNumber());
            zs.add((1000 * Math.cos(rad)).toNumber());
        }
        return det.feed(xs, ys, zs, PERIOD);
    }

    // Rest, then a twist out to `deg` held for 5 samples (200 ms), then back to rest.
    function twist(det as TwistDetector, deg as Number) as Number {
        return tilt(det, deg, 5) + tilt(det, 0, 5);
    }
}

(:test)
function twistStillWristDoesNothing(logger as Logger) as Boolean {
    var det = new TwistDetector(45, true);
    var fired = TwistFixture.tilt(det, 0, 250);
    return fired == 0 && det.twists == 0;
}

(:test)
function twistDoubleSwitchesOnce(logger as Logger) as Boolean {
    var det = new TwistDetector(45, true);
    TwistFixture.tilt(det, 0, 25);
    var fired = TwistFixture.twist(det, 70) + TwistFixture.twist(det, 70);
    logger.debug("twists " + det.twists + " switches " + det.switches);
    return fired == 1 && det.twists == 2;
}

(:test)
function twistSingleNeedsSecondWhenDouble(logger as Logger) as Boolean {
    var det = new TwistDetector(45, true);
    TwistFixture.tilt(det, 0, 25);
    var fired = TwistFixture.twist(det, 70) + TwistFixture.tilt(det, 0, 50);
    return fired == 0 && det.twists == 1;
}

(:test)
function twistSingleModeSwitchesOnOne(logger as Logger) as Boolean {
    var det = new TwistDetector(45, false);
    TwistFixture.tilt(det, 0, 25);
    return TwistFixture.twist(det, 70) == 1;
}

(:test)
function twistSmallWobbleIgnored(logger as Logger) as Boolean {
    var det = new TwistDetector(45, true);
    TwistFixture.tilt(det, 0, 25);
    var fired = TwistFixture.twist(det, 25) + TwistFixture.twist(det, 25);
    return fired == 0 && det.twists == 0;
}

(:test)
function twistHeldTiltReanchors(logger as Logger) as Boolean {
    // Hand moves to a new position and stays there: no switch, and the new
    // position becomes the rest pose.
    var det = new TwistDetector(45, true);
    TwistFixture.tilt(det, 0, 25);
    var fired = TwistFixture.tilt(det, 70, 50);
    fired += TwistFixture.tilt(det, 70, 50);
    return fired == 0 && det.twists == 0;
}

(:test)
function twistBumpsSkipped(logger as Logger) as Boolean {
    var det = new TwistDetector(45, true);
    TwistFixture.tilt(det, 0, 25);
    var fired = det.feed([0, 0, 0, 0], [0, 2000, 0, -1800], [2500, 300, 200, 2600], TwistFixture.PERIOD);
    return fired == 0 && det.bumps == 4;
}

(:test)
function twistCooldownAfterSwitch(logger as Logger) as Boolean {
    // Four quick twists back to back give one switch: the second pair falls in the cooldown.
    var det = new TwistDetector(45, true);
    TwistFixture.tilt(det, 0, 25);
    var fired = 0;
    for (var i = 0; i < 4; i++) {
        fired += TwistFixture.twist(det, 70);
    }
    return fired == 1;
}

(:test)
function twistDefaultAngleCatchesSmallerTwist(logger as Logger) as Boolean {
    // At the 35° default a 40° double twist is enough.
    var det = new TwistDetector(35, true);
    TwistFixture.tilt(det, 0, 25);
    var fired = TwistFixture.twist(det, 40) + TwistFixture.twist(det, 40);
    return fired == 1 && det.twists == 2;
}

(:test)
function twistSlowTwistCounts(logger as Logger) as Boolean {
    // Held out for 880 ms before coming back: still a twist, not a new hand position.
    var det = new TwistDetector(35, true);
    TwistFixture.tilt(det, 0, 25);
    var fired = 0;
    for (var i = 0; i < 2; i++) {
        fired += TwistFixture.tilt(det, 60, 22) + TwistFixture.tilt(det, 0, 5);
    }
    return fired == 1 && det.twists == 2;
}

(:test)
function twistDefaultSingleSwitches(logger as Logger) as Boolean {
    // Default settings: one twist switches, and a second one right after falls in the cooldown.
    var det = new TwistDetector(TwistDetector.DEFAULT_ANGLE, TwistDetector.DEFAULT_PAIR);
    TwistFixture.tilt(det, 0, 25);
    var first = TwistFixture.twist(det, 50);
    var second = TwistFixture.twist(det, 50);
    var later = TwistFixture.tilt(det, 0, 30) + TwistFixture.twist(det, 50);
    return first == 1 && second == 0 && later == 1;
}
