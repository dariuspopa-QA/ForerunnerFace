import Toybox.Lang;
import Toybox.Math;

// Spots a quick wrist twist in raw accelerometer samples (milli-g), whatever way the watch sits.
//
// It tracks where gravity normally points (a slow average) and measures how far each sample
// tilts away from it. A twist is a tilt past the threshold that comes back within TWIST_MAX_MS.
// A tilt that stays (moving the hand from the hoods to the drops) re-anchors the baseline instead.
// Samples far from 1 g are road bumps and are skipped. By default one twist is one switch,
// and COOLDOWN_MS stops it switching twice. With `pair` set, two twists within PAIR_MS make
// one switch instead, so a single jolt never changes the page.
class TwistDetector {

    // Defaults for the TwistAngle and PairTwists settings.
    static const DEFAULT_ANGLE = 35;
    static const DEFAULT_PAIR = false;

    const TWIST_MAX_MS = 1000;
    const PAIR_MS = 1500;
    const COOLDOWN_MS = 1000;
    const BASELINE_ALPHA = 0.02;
    const MIN_G = 600.0;
    const MAX_G = 1400.0;

    var twists as Number = 0;     // single twists seen
    var switches as Number = 0;   // gestures that changed the page
    var bumps as Number = 0;      // samples skipped as road shocks

    private var _pair as Boolean;
    private var _outCos as Float = 0.0;
    private var _backCos as Float = 0.0;

    private var _bx as Float = 0.0;
    private var _by as Float = 0.0;
    private var _bz as Float = 0.0;
    private var _hasBase as Boolean = false;

    private var _now as Number = 0;
    private var _outSince as Number = -1;
    private var _lastTwist as Number = -100000;
    private var _quietUntil as Number = 0;

    function initialize(angleDeg as Number, pair as Boolean) {
        _pair = pair;
        setAngle(angleDeg);
    }

    function setAngle(angleDeg as Number) as Void {
        var rad = angleDeg * Math.PI / 180.0;
        _outCos = Math.cos(rad).toFloat();
        _backCos = Math.cos(rad / 2.0).toFloat();
    }

    function setPair(pair as Boolean) as Void {
        _pair = pair;
    }

    // Feeds one batch of samples taken `periodMs` apart. Returns how many page switches it holds.
    function feed(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>, periodMs as Number) as Number {
        var fired = 0;
        for (var i = 0; i < xs.size(); i++) {
            _now += periodMs;
            if (sample(xs[i].toFloat(), ys[i].toFloat(), zs[i].toFloat())) {
                fired++;
            }
        }
        return fired;
    }

    private function sample(x as Float, y as Float, z as Float) as Boolean {
        var m = Math.sqrt(x * x + y * y + z * z).toFloat();
        if (m < MIN_G || m > MAX_G) {
            bumps++;
            return false;
        }
        x /= m; y /= m; z /= m;
        if (!_hasBase) {
            _bx = x; _by = y; _bz = z;
            _hasBase = true;
            return false;
        }
        var dot = x * _bx + y * _by + z * _bz;

        if (_outSince < 0) {
            if (dot < _outCos) {
                _outSince = _now;
            } else {
                drift(x, y, z);
            }
            return false;
        }

        // Tilted away: either it comes back (a twist) or it stays (a new hand position).
        if (dot > _backCos) {
            _outSince = -1;
            return twist();
        }
        if (_now - _outSince > TWIST_MAX_MS) {
            _bx = x; _by = y; _bz = z;
            _outSince = -1;
        }
        return false;
    }

    private function twist() as Boolean {
        twists++;
        if (_now < _quietUntil) {
            return false;
        }
        if (_pair && _now - _lastTwist > PAIR_MS) {
            _lastTwist = _now;
            return false;
        }
        _lastTwist = -100000;
        _quietUntil = _now + COOLDOWN_MS;
        switches++;
        return true;
    }

    private function drift(x as Float, y as Float, z as Float) as Void {
        var a = BASELINE_ALPHA;
        var bx = _bx + (x - _bx) * a;
        var by = _by + (y - _by) * a;
        var bz = _bz + (z - _bz) * a;
        var n = Math.sqrt(bx * bx + by * by + bz * bz).toFloat();
        if (n > 0.0) {
            _bx = bx / n; _by = by / n; _bz = bz / n;
        }
    }
}
