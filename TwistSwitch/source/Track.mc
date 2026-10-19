import Toybox.Lang;
import Toybox.Math;

// The ride's breadcrumb for the map page: GPS fixes kept while recording, pure and unit tested.
//
// A fix is kept once it is MIN_M from the last kept one, so standing still adds nothing.
// Past MAX_POINTS every other point is dropped and the spacing doubles, so a long ride keeps
// its whole shape at lower detail.
class Track {

    const MAX_POINTS = 500;
    const MIN_M = 20.0;

    var lats as Array<Float> = [] as Array<Float>;
    var lons as Array<Float> = [] as Array<Float>;

    // Latest fix, recording or not, for the "you are here" dot.
    var curLat as Float? = null;
    var curLon as Float? = null;

    private var _spacing as Float = MIN_M;

    function initialize() {
    }

    function onFix(lat as Float, lon as Float, recording as Boolean) as Void {
        curLat = lat;
        curLon = lon;
        if (!recording) {
            return;
        }
        var n = lats.size();
        if (n > 0 && distanceM(lats[n - 1], lons[n - 1], lat, lon) < _spacing) {
            return;
        }
        lats.add(lat);
        lons.add(lon);
        if (lats.size() > MAX_POINTS) {
            thin();
        }
    }

    function clear() as Void {
        lats = [] as Array<Float>;
        lons = [] as Array<Float>;
        _spacing = MIN_M;
    }

    // Keeps every other point plus the newest one.
    private function thin() as Void {
        var n = lats.size();
        var la = [] as Array<Float>;
        var lo = [] as Array<Float>;
        for (var i = 0; i < n; i += 2) {
            la.add(lats[i]);
            lo.add(lons[i]);
        }
        if ((n - 1) % 2 != 0) {
            la.add(lats[n - 1]);
            lo.add(lons[n - 1]);
        }
        lats = la;
        lons = lo;
        _spacing *= 2;
    }

    // Flat-earth metres, plenty for points a few metres to a few km apart.
    static function distanceM(lat1 as Float, lon1 as Float, lat2 as Float, lon2 as Float) as Float {
        var dx = eastM(lon2 - lon1, lat1);
        var dy = northM(lat2 - lat1);
        return Math.sqrt(dx * dx + dy * dy).toFloat();
    }

    static function eastM(dLon as Float, atLat as Float) as Float {
        return (dLon * 111320.0 * Math.cos(atLat * Math.PI / 180.0)).toFloat();
    }

    static function northM(dLat as Float) as Float {
        return (dLat * 110540.0).toFloat();
    }
}
