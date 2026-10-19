import Toybox.Lang;
import Toybox.WatchUi;

// Owns the page order and swaps pages with the same slide a swipe up would give.
class Pager {

    const PAGES = 3;   // 0 ride stats, 1 body and climb, 2 map

    var index as Number = 0;
    var locked as Boolean = false;   // pause menu is up: twists must not swap it away
    private var _ride as Ride;
    private var _detector as TwistDetector;

    function initialize(ride as Ride, detector as TwistDetector) {
        _ride = ride;
        _detector = detector;
    }

    function initialView() as [WatchUi.Views, WatchUi.InputDelegates] {
        return [viewFor(index), new RideDelegate(self, _ride)];
    }

    function show(step as Number) as Void {
        if (locked) {
            return;
        }
        index = (index + step + PAGES) % PAGES;
        var slide = step > 0 ? WatchUi.SLIDE_UP : WatchUi.SLIDE_DOWN;
        WatchUi.switchToView(viewFor(index), new RideDelegate(self, _ride), slide);
    }

    private function viewFor(i as Number) as WatchUi.View {
        if (i == 2) {
            return new MapPage(_ride, _detector, i, PAGES);
        }
        return new StatsPage(_ride, _detector, i, PAGES);
    }
}
