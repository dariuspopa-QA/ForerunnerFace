import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Receives a missed-call count from a companion phone app.
// Expected message: { "missedCalls": 3 }  or just the number 3.
(:background)
class MissedCallService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(msg) as Void {
        var data = msg.data;
        var count = null;
        if (data instanceof Dictionary) {
            count = data["missedCalls"];
        } else if (data instanceof Number) {
            count = data;
        }
        Background.exit(count);
    }
}
