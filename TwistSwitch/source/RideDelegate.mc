import Toybox.Lang;
import Toybox.WatchUi;

// Buttons and swipes still work: UP/DOWN and swipes page, START starts or pauses,
// BACK marks a lap while riding.
class RideDelegate extends WatchUi.BehaviorDelegate {

    private var _pager as Pager;
    private var _ride as Ride;

    function initialize(pager as Pager, ride as Ride) {
        BehaviorDelegate.initialize();
        _pager = pager;
        _ride = ride;
    }

    function onNextPage() as Boolean {
        _pager.show(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _pager.show(-1);
        return true;
    }

    function onSelect() as Boolean {
        if (_ride.isRecording()) {
            _ride.pause();
            PauseMenu.push(_pager, _ride);
        } else if (_ride.isOpen()) {
            PauseMenu.push(_pager, _ride);
        } else {
            _ride.start();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (_ride.isRecording()) {
            _ride.lap();
            return true;
        }
        if (_ride.isOpen()) {
            PauseMenu.push(_pager, _ride);
            return true;
        }
        return false;   // nothing recorded: leave the app
    }
}

module PauseMenu {
    function push(pager as Pager, ride as Ride) as Void {
        pager.locked = true;
        var menu = new WatchUi.Menu2({ :title => WatchUi.loadResource(Rez.Strings.MenuTitle) as String });
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuResume, null, :resume, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuSave, null, :save, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuDiscard, null, :discard, null));
        WatchUi.pushView(menu, new PauseMenuDelegate(pager, ride), WatchUi.SLIDE_LEFT);
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _pager as Pager;
    private var _ride as Ride;

    function initialize(pager as Pager, ride as Ride) {
        Menu2InputDelegate.initialize();
        _pager = pager;
        _ride = ride;
    }

    function onBack() as Void {
        _pager.locked = false;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resume) {
            _ride.start();
        } else if (id == :save) {
            _ride.save();
            getApp().track.clear();
        } else if (id == :discard) {
            _ride.discard();
            getApp().track.clear();
        }
        _pager.locked = false;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
