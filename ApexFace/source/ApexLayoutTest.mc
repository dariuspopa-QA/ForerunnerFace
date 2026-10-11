import Toybox.Lang;
import Toybox.Test;

// Unit tests for geometry and colour rules.

// ---- Colours ----------------------------------------------------------

// Seconds trail: accent at 55 % visual weight over black.
(:test)
function blendScalesEachChannel(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.blend(0xC8FF2E, 0.55f), 0x6E8C19);
    ApexTestUtil.assertEqual(ApexLayout.blend(0xFFFFFF, 0.5f), 0x7F7F7F);
    return true;
}

(:test)
function blendKeepsColourAtFullWeightAndBlacksOutAtZero(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.blend(0xFF5A1F, 1.0f), 0xFF5A1F);
    ApexTestUtil.assertEqual(ApexLayout.blend(0xFF5A1F, 0.0f), 0x000000);
    return true;
}

(:test)
function numeralColorUsesAccentForSentinel(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.numeralColor(ApexLayout.NUMERALS_ACCENT, 0x4FD1FF), 0x4FD1FF);
    ApexTestUtil.assertEqual(ApexLayout.numeralColor(0xE9DFC9, 0x4FD1FF), 0xE9DFC9);
    ApexTestUtil.assertEqual(ApexLayout.numeralColor(0x000000, 0x4FD1FF), 0x000000);
    return true;
}

(:test)
function ringGreysUseDesignGreysOnAmoled(logger as Logger) as Boolean {
    var greys = ApexLayout.ringGreys(true);
    ApexTestUtil.assertEqual(greys[0], 0x34342F);
    ApexTestUtil.assertEqual(greys[1], 0x2A2A28);
    return true;
}

// On 64-colour MIP screens every grey must survive rounding to the 00/55/AA/FF palette.
(:test)
function ringGreysStayVisibleOnMip(logger as Logger) as Boolean {
    var greys = ApexLayout.ringGreys(false);
    for (var i = 0; i < greys.size(); i++) {
        for (var shift = 0; shift <= 16; shift += 8) {
            var channel = (greys[i] >> shift) & 0xFF;
            Test.assertMessage(channel >= 0x55 && channel % 0x55 == 0, "grey channel " + channel + " not on the MIP palette");
        }
    }
    return true;
}

// ---- Night palette ----------------------------------------------------

(:test)
function dayPaletteUsesSettingsAndScreenGreys(logger as Logger) as Boolean {
    var day = [0xC8FF2E, 0xF4F4EF, 0xCFE3FF, 0xB0B0AA];
    var p = ApexLayout.palette(day, true, false);
    ApexTestUtil.assertEqual(p[ApexLayout.P_ACCENT], 0xC8FF2E);
    ApexTestUtil.assertEqual(p[ApexLayout.P_NUMERALS], 0xF4F4EF);
    ApexTestUtil.assertEqual(p[ApexLayout.P_INK], 0xCFE3FF);
    ApexTestUtil.assertEqual(p[ApexLayout.P_DIM], 0xB0B0AA);
    ApexTestUtil.assertEqual(p[ApexLayout.P_MINOR], 0x34342F);
    ApexTestUtil.assertEqual(p[ApexLayout.P_RULE], 0x2A2A28);
    ApexTestUtil.assertEqual(p[ApexLayout.P_AOD_MAJOR], 0x4A4A46);
    ApexTestUtil.assertEqual(ApexLayout.palette(day, false, false)[ApexLayout.P_RULE], 0x555555);
    return true;
}

// CLAUDE.md, Colours, Night column: everything red whatever the settings.
(:test)
function nightPaletteIsRedWhateverTheSettings(logger as Logger) as Boolean {
    var p = ApexLayout.palette([0x4FD1FF, 0xCFE3FF, 0xF4F4EF, 0x98A6B4], true, true);
    ApexTestUtil.assertEqual(p[ApexLayout.P_ACCENT], 0xFF4A3D);
    ApexTestUtil.assertEqual(p[ApexLayout.P_NUMERALS], 0xFF4A3D);
    ApexTestUtil.assertEqual(p[ApexLayout.P_INK], 0xFF4A3D);
    ApexTestUtil.assertEqual(p[ApexLayout.P_DIM], 0xB3392E);
    ApexTestUtil.assertEqual(p[ApexLayout.P_MINOR], 0x3A120E);
    ApexTestUtil.assertEqual(p[ApexLayout.P_RULE], 0x3A120E);
    for (var i = 0; i < p.size(); i++) {
        var c = p[i];
        Test.assertMessage(((c >> 8) & 0xFF) <= ((c >> 16) & 0xFF) / 2, "night colour " + i + " is not red");
    }
    return true;
}

(:test)
function nightPaletteStaysVisibleOnMip(logger as Logger) as Boolean {
    var p = ApexLayout.palette([0, 0, 0, 0], false, true);
    ApexTestUtil.assertEqual(p[ApexLayout.P_RULE], 0x550000);
    ApexTestUtil.assertEqual(p[ApexLayout.P_MINOR], 0x550000);
    return true;
}

(:test)
function sleepWindowWithinOneDay(logger as Logger) as Boolean {
    // sleep 13:00, wake 15:00 (a nap profile)
    Test.assert(ApexLayout.inSleepWindow(13 * 60, 13 * 60, 15 * 60));
    Test.assert(ApexLayout.inSleepWindow(14 * 60, 13 * 60, 15 * 60));
    Test.assert(!ApexLayout.inSleepWindow(15 * 60, 13 * 60, 15 * 60));
    Test.assert(!ApexLayout.inSleepWindow(12 * 60, 13 * 60, 15 * 60));
    return true;
}

(:test)
function sleepWindowAcrossMidnight(logger as Logger) as Boolean {
    var sleep = 22 * 60 + 30;   // 22:30
    var wake = 6 * 60 + 45;     // 06:45
    Test.assert(ApexLayout.inSleepWindow(23 * 60, sleep, wake));
    Test.assert(ApexLayout.inSleepWindow(0, sleep, wake));
    Test.assert(ApexLayout.inSleepWindow(6 * 60 + 44, sleep, wake));
    Test.assert(!ApexLayout.inSleepWindow(6 * 60 + 45, sleep, wake));
    Test.assert(!ApexLayout.inSleepWindow(12 * 60, sleep, wake));
    Test.assert(!ApexLayout.inSleepWindow(22 * 60 + 29, sleep, wake));
    return true;
}

(:test)
function sleepWindowEmptyWhenSleepEqualsWake(logger as Logger) as Boolean {
    Test.assert(!ApexLayout.inSleepWindow(0, 0, 0));
    Test.assert(!ApexLayout.inSleepWindow(600, 600, 600));
    return true;
}

// ---- Pen widths (all screen sizes) --------------------------------------

(:test)
function penWidthScalesOnAmoled(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.penWidth(4.0f, 1.0f, true), 4.0f);
    ApexTestUtil.assertNear(ApexLayout.penWidth(1.4f, 1.0f, true), 1.4f, 0.001f, "minor tick at 454 px");
    ApexTestUtil.assertNear(ApexLayout.penWidth(3.0f, 416.0f / 454, true), 2.749f, 0.001f, "major tick at 416 px");
    return true;
}

(:test)
function penWidthNeverDropsBelowOnePixel(logger as Logger) as Boolean {
    var smallest = 218.0f / 454;   // fr255s
    ApexTestUtil.assertEqual(ApexLayout.penWidth(1.4f, smallest, true), 1.0f);
    ApexTestUtil.assertEqual(ApexLayout.penWidth(1.4f, smallest, false), 1);
    ApexTestUtil.assertEqual(ApexLayout.penWidth(1.0f, smallest, false), 1);
    return true;
}

(:test)
function penWidthIsWholePixelsOnMip(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.penWidth(4.0f, 260.0f / 454, false), 2);   // 2.29
    ApexTestUtil.assertEqual(ApexLayout.penWidth(3.0f, 280.0f / 454, false), 2);   // 1.85
    Test.assert(ApexLayout.penWidth(4.0f, 260.0f / 454, false) instanceof Number);
    return true;
}

// ---- Font fallback (screens without scalable fonts) ---------------------

(:test)
function pickFontTakesTallestThatFits(logger as Logger) as Boolean {
    var heights = [19, 23, 27, 32, 40];               // XTINY .. LARGE
    ApexTestUtil.assertEqual(ApexLayout.pickFont(heights, 16.0f), 0);   // limit 20.8: 19 fits, 23 doesn't
    ApexTestUtil.assertEqual(ApexLayout.pickFont(heights, 26.0f), 3);   // limit 33.8: 32
    return true;
}

(:test)
function pickFontMatchesTargetSizes(logger as Logger) as Boolean {
    var heights = [19, 23, 27, 32, 40];
    ApexTestUtil.assertEqual(ApexLayout.pickFont(heights, 15.0f), 0);   // limit 19.5
    ApexTestUtil.assertEqual(ApexLayout.pickFont(heights, 21.0f), 2);   // limit 27.3
    ApexTestUtil.assertEqual(ApexLayout.pickFont(heights, 100.0f), 4);
    return true;
}

(:test)
function pickFontFallsBackToSmallest(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.pickFont([23, 19, 27], 5.0f), 1);
    return true;
}

(:test)
function rowExtentForCapHeightFonts(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.rowExtent(20, true, 1.0f), 14.0f);          // 10 + 4 px gap
    ApexTestUtil.assertEqual(ApexLayout.rowExtent(10, true, 218.0f / 454), 7.0f);   // gap never below 2 px
    return true;
}

(:test)
function rowExtentForSystemFonts(logger as Logger) as Boolean {
    ApexTestUtil.assertNear(ApexLayout.rowExtent(40, false, 1.0f), 17.0f, 0.001f, "line height with leading");
    return true;
}

(:test)
function rowBelowKeepsDesignPositionWhenThereIsRoom(logger as Logger) as Boolean {
    // 454 px: label 290 (Mono16, cap 11 -> extent 9.5), value 316 (Value 28, cap 20 -> extent 14)
    ApexTestUtil.assertEqual(ApexLayout.rowBelow(290.0f, 316.0f, 9.5f, 14.0f), 316.0f);
    return true;
}

(:test)
function rowBelowPushesDownWhenFontsAreTall(logger as Logger) as Boolean {
    // 218 px MIP with system fonts 19 + 23 px tall: extents 8.075 + 9.775
    var y = ApexLayout.rowBelow(139.0f, 152.0f, 8.075f, 9.775f);
    ApexTestUtil.assertNear(y, 156.85f, 0.01f, "pushed value row");
    return true;
}

(:test)
function rowAboveKeepsDesignPositionWhenThereIsRoom(logger as Logger) as Boolean {
    // 454 px: readout value 389 (ArcValue 26, extent 13.5), label 412 (Mono14, extent 9)
    ApexTestUtil.assertEqual(ApexLayout.rowAbove(412.0f, 389.0f, 9.0f, 13.5f), 389.0f);
    return true;
}

(:test)
function rowAbovePullsUpWhenFontsAreTall(logger as Logger) as Boolean {
    // 360 px with system fonts 30 + 30 px tall: extents 12.75 each
    var y = ApexLayout.rowAbove(326.7f, 308.5f, 12.75f, 12.75f);
    ApexTestUtil.assertNear(y, 301.2f, 0.01f, "pulled-up readout value");
    return true;
}


// ---- Seconds ----------------------------------------------------------

(:test)
function trailEndRunsClockwiseFromTwelve(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.trailEnd(0), 90);
    ApexTestUtil.assertEqual(ApexLayout.trailEnd(15), 0);
    ApexTestUtil.assertEqual(ApexLayout.trailEnd(30), -90);
    ApexTestUtil.assertEqual(ApexLayout.trailEnd(45), -180);
    ApexTestUtil.assertEqual(ApexLayout.trailEnd(59), -264);
    return true;
}

// Comet: r 224 -> 202 at 12 o'clock is y 3 -> 25.
(:test)
function cometAtTwelveSpansYThreeToTwentyFive(logger as Logger) as Boolean {
    var outer = ApexLayout.clockPoint(0, 224.0f);
    var inner = ApexLayout.clockPoint(0, 202.0f);
    ApexTestUtil.assertNear(ApexLayout.C + outer[1], 3, 0.01f, "outer y");
    ApexTestUtil.assertNear(ApexLayout.C + inner[1], 25, 0.01f, "inner y");
    ApexTestUtil.assertNear(outer[0], 0, 0.01f, "outer x");
    return true;
}

// ---- Partial updates (MIP low power) --------------------------------------

// At 12 o'clock the comet spans y 3..25 (r 224..202), the trail sits at r 226 (y 1).
(:test)
function cometBoxAtTwelveCoversCometAndTrail(logger as Logger) as Boolean {
    var box = ApexLayout.cometBox(0, 1.0f);
    Test.assert(box[1] <= 0 && box[1] + box[3] >= 25);       // y: trail .. inner end
    Test.assert(box[0] <= 225 && box[0] + box[2] >= 229);    // x: comet width 4 around 227
    Test.assertMessage(box[2] * box[3] < 400, "box too big: " + box[2] + "x" + box[3]);
    return true;
}

(:test)
function cometBoxStaysSmallAtEveryAngle(logger as Logger) as Boolean {
    for (var sec = 0; sec < 60; sec++) {
        var box = ApexLayout.cometBox(sec, 1.0f);
        Test.assertMessage(box[2] > 0 && box[3] > 0, "empty box at " + sec);
        Test.assertMessage(box[2] <= 32 && box[3] <= 32, "box at " + sec + " is " + box[2] + "x" + box[3]);
        Test.assert(box[0] >= -4 && box[1] >= -4 && box[0] + box[2] <= 458 && box[1] + box[3] <= 458);   // a few px off-screen is fine (clipped)
    }
    return true;
}

(:test)
function cometBoxScalesWithTheScreen(logger as Logger) as Boolean {
    var box = ApexLayout.cometBox(15, 260.0f / 454);   // 3 o'clock on a 260 px screen
    Test.assert(box[0] <= 245 && box[0] + box[2] >= 259);
    Test.assert(box[1] <= 129 && box[1] + box[3] >= 131);
    return true;
}

(:test)
function unionBoxCoversBoth(logger as Logger) as Boolean {
    var u = ApexLayout.unionBox([10, 20, 5, 5] as [Number, Number, Number, Number], [12, 30, 10, 4] as [Number, Number, Number, Number]);
    ApexTestUtil.assertEqual(u[0], 10);
    ApexTestUtil.assertEqual(u[1], 20);
    ApexTestUtil.assertEqual(u[2], 12);
    ApexTestUtil.assertEqual(u[3], 14);
    return true;
}

// ---- Points on circles -------------------------------------------------

(:test)
function clockPointFollowsClockAngles(logger as Logger) as Boolean {
    var cases = [[0, 0, -100], [90, 100, 0], [180, 0, 100], [270, -100, 0]];
    for (var i = 0; i < cases.size(); i++) {
        var p = ApexLayout.clockPoint(cases[i][0], 100.0f);
        ApexTestUtil.assertNear(p[0], cases[i][1], 0.01f, "x at " + cases[i][0]);
        ApexTestUtil.assertNear(p[1], cases[i][2], 0.01f, "y at " + cases[i][0]);
    }
    return true;
}

(:test)
function ciqPointFollowsCiqAngles(logger as Logger) as Boolean {
    var cases = [[0, 100, 0], [90, 0, -100], [180, -100, 0], [270, 0, 100]];
    for (var i = 0; i < cases.size(); i++) {
        var p = ApexLayout.ciqPoint(cases[i][0], 100.0f);
        ApexTestUtil.assertNear(p[0], cases[i][1], 0.01f, "x at " + cases[i][0]);
        ApexTestUtil.assertNear(p[1], cases[i][2], 0.01f, "y at " + cases[i][0]);
    }
    return true;
}

// ---- Arc ----------------------------------------------------------------

// Arc runs from clock 225 (bottom-left) to clock 135 (bottom-right).
(:test)
function arcEndsSitAtBottomLeftAndBottomRight(logger as Logger) as Boolean {
    var start = ApexLayout.ciqPoint(ApexLayout.ARC_START, 198.0f);
    var startClock = ApexLayout.clockPoint(225, 198.0f);
    ApexTestUtil.assertNear(start[0], startClock[0], 0.01f, "start x");
    ApexTestUtil.assertNear(start[1], startClock[1], 0.01f, "start y");
    Test.assert(start[0] < 0 && start[1] > 0);

    var end = ApexLayout.ciqPoint(ApexLayout.ARC_START - ApexLayout.ARC_SWEEP, 198.0f);
    var endClock = ApexLayout.clockPoint(135, 198.0f);
    ApexTestUtil.assertNear(end[0], endClock[0], 0.01f, "end x");
    ApexTestUtil.assertNear(end[1], endClock[1], 0.01f, "end y");
    return true;
}

(:test)
function arcSweepIsTwoSeventyTimesFraction(logger as Logger) as Boolean {
    ApexTestUtil.assertEqual(ApexLayout.arcSweep(null), 0.0f);
    ApexTestUtil.assertEqual(ApexLayout.arcSweep(0.0f), 0.0f);
    ApexTestUtil.assertEqual(ApexLayout.arcSweep(0.5f), 135.0f);
    ApexTestUtil.assertEqual(ApexLayout.arcSweep(1.0f), 270.0f);
    ApexTestUtil.assertNear(ApexLayout.arcSweep(0.72f), 194.4f, 0.01f, "72 %");
    return true;
}

// The half-full arc ends at 12 o'clock.
(:test)
function halfArcEndsAtTwelve(logger as Logger) as Boolean {
    var p = ApexLayout.ciqPoint(ApexLayout.ARC_START - ApexLayout.arcSweep(0.5f), 198.0f);
    ApexTestUtil.assertNear(p[0], 0, 0.01f, "x");
    ApexTestUtil.assertNear(p[1], -198, 0.01f, "y");
    return true;
}

// ---- Field row ----------------------------------------------------------

(:test)
function fieldColumnsCentreThreeColumns(logger as Logger) as Boolean {
    var lefts = ApexLayout.fieldColumns([100.0f, 100.0f, 100.0f], 36.0f, 227.0f);
    ApexTestUtil.assertEqual(lefts[0], 41.0f);
    ApexTestUtil.assertEqual(lefts[1], 177.0f);
    ApexTestUtil.assertEqual(lefts[2], 313.0f);
    return true;
}

(:test)
function fieldColumnsRecentreWithoutEmptySlots(logger as Logger) as Boolean {
    var lefts = ApexLayout.fieldColumns([100.0f, null, 100.0f], 36.0f, 227.0f);
    ApexTestUtil.assertEqual(lefts[0], 109.0f);
    ApexTestUtil.assertEqual(lefts[1], null);
    ApexTestUtil.assertEqual(lefts[2], 245.0f);

    var single = ApexLayout.fieldColumns([null, null, 60.0f], 36.0f, 227.0f);
    ApexTestUtil.assertEqual(single[0], null);
    ApexTestUtil.assertEqual(single[1], null);
    ApexTestUtil.assertEqual(single[2], 197.0f);
    return true;
}

(:test)
function fieldColumnsKeepUnevenRowCentred(logger as Logger) as Boolean {
    var widths = [40.0f, 90.0f, 60.0f];
    var lefts = ApexLayout.fieldColumns(widths, 36.0f, 227.0f);
    var left = lefts[0] as Float;
    var right = (lefts[2] as Float) + widths[2];
    ApexTestUtil.assertNear((left + right) / 2, 227, 0.01f, "row centre");
    ApexTestUtil.assertNear((lefts[1] as Float) - (left + widths[0]), 36, 0.01f, "gap 1");
    ApexTestUtil.assertNear((lefts[2] as Float) - ((lefts[1] as Float) + widths[1]), 36, 0.01f, "gap 2");
    return true;
}

(:test)
function fieldColumnsAllEmpty(logger as Logger) as Boolean {
    var lefts = ApexLayout.fieldColumns([null, null, null], 36.0f, 227.0f);
    ApexTestUtil.assertEqual(lefts.size(), 3);
    ApexTestUtil.assertEqual(lefts[0], null);
    ApexTestUtil.assertEqual(lefts[1], null);
    ApexTestUtil.assertEqual(lefts[2], null);
    return true;
}

// ---- Editor hit testing -------------------------------------------------

(:test)
function boxContainsIncludesEdges(logger as Logger) as Boolean {
    var box = [100, 280, 60, 50] as [Number, Number, Number, Number];
    Test.assert(ApexLayout.boxContains(box, 100, 280));
    Test.assert(ApexLayout.boxContains(box, 160, 330));
    Test.assert(ApexLayout.boxContains(box, 130, 300));
    Test.assert(!ApexLayout.boxContains(box, 99, 300));
    Test.assert(!ApexLayout.boxContains(box, 161, 300));
    Test.assert(!ApexLayout.boxContains(box, 130, 331));
    Test.assert(!ApexLayout.boxContains(null, 130, 300));
    return true;
}

(:test)
function inArcZoneCoversRimAndReadout(logger as Logger) as Boolean {
    Test.assert(ApexLayout.inArcZone(0.0f, -200.0f));      // rim at 12
    Test.assert(ApexLayout.inArcZone(-150.0f, 150.0f));    // bottom-left arc end
    Test.assert(ApexLayout.inArcZone(0.0f, 162.0f));       // readout value (227, 389)
    Test.assert(ApexLayout.inArcZone(0.0f, 185.0f));       // readout label (227, 412)
    return true;
}

(:test)
function inArcZoneLeavesTimeAndFieldsAlone(logger as Logger) as Boolean {
    Test.assert(!ApexLayout.inArcZone(0.0f, 0.0f));        // centre
    Test.assert(!ApexLayout.inArcZone(-60.0f, -42.0f));    // hours
    Test.assert(!ApexLayout.inArcZone(0.0f, 89.0f));       // field values (y 316)
    Test.assert(!ApexLayout.inArcZone(120.0f, 89.0f));     // right field
    Test.assert(!ApexLayout.inArcZone(0.0f, 140.0f));      // just above the readout
    Test.assert(!ApexLayout.inArcZone(75.0f, 150.0f));     // beside the readout, inside the ring
    return true;
}
