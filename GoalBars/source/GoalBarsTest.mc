import Toybox.Lang;
import Toybox.Test;

// GoalBars's own tests: what this face customizes, i.e. its drawing in every display mode
// and with every value of its phone settings. The shared core is tested in FaceCore/test.
(:test)
module GoalBarsTest {

    (:test)
    function drawsEveryMode(logger as Logger) as Boolean {
        FaceTestUtil.renderEveryMode(new GoalBarsView(false));
        // Inside the on-watch editor (never Always-On there)
        FaceTestUtil.renderEveryMode(new GoalBarsView(true));
        return true;
    }

    (:test)
    function drawsEverySettingValue(logger as Logger) as Boolean {
        var view = new GoalBarsView(false);
        FaceTestUtil.eachSettingValue(view, {
            "Layout" => [0, 1],
            "AccentColor" => [0, 1, 2, 3, 4],
            "BgStyle" => [0, 1, 2, 3, 4, 5, 6, 7, 8],
            "BgIntensity" => [0, 1, 2],
            "BgColor" => [0, 1],
            "ClockMode" => [0, 1, 2],
            "TimeWeight" => [0, 1],
            "DateFormat" => [0, 1, 2, 3, 4],
            "Bar1" => [0, 1, 2, 3, 4, 5, 6],
            "Bar2" => [0, 1, 2, 3, 4, 5, 6],
            "Bar3" => [0, 1, 2, 3, 4, 5, 6],
            "Bar4" => [0, 1, 2, 3, 4, 5, 6],
            "CaloriesGoal" => [0, 1, 2, 3],
            "ShowPace" => [true, false],
            "ShowNotifications" => [true, false],
            "ShowAlarms" => [true, false],
            "ShowDnd" => [true, false],
            "AodShowDate" => [true, false]
        }, view.method(:loadSettings), true);
        return true;
    }
}
