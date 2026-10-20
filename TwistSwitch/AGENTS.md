# Twist Switch — Connect IQ watch app (not a face)

A bike ride app for fr965/fr970 whose pages change on a wrist twist, so you can flip
between stats and map one-handed while holding the bars.

## Why it records the ride itself

Connect IQ has no way to inject a swipe or button press into another app or into the
built-in Bike activity, and data fields can't read the fast accelerometer stream. So the
app is a full `watch-app` that records its own cycling FIT activity (it lands in Garmin
Connect like a normal ride) and hosts its own pages. It does not do course navigation.

## Layout

- `source/TwistDetector.mc` — gesture logic, pure and unit tested (`TwistDetectorTest.mc`).
  Gravity-angle based, axis agnostic: tilt past the threshold and back within 1 s is a
  twist; one twist is a switch, with a 1 s cooldown (or two within 1.5 s with PairTwists on);
  samples outside 0.6–1.4 g are bumps.
- `source/TwistSwitchApp.mc` — 25 Hz accelerometer listener, GPS, settings, vibrate on switch.
  The sensor callback only flags a switch; a 50 ms one-shot timer changes the view.
- `source/Track.mc` — breadcrumb of GPS fixes while recording (20 m apart, thinned past
  500 points), unit tested (`TrackTest.mc`).
- `source/Pager.mc` — page order (0 stats, 1 HR/climb, 2 map), slides up like a swipe.
- `source/Pages.mc` — StatsPage and MapPage, shared chrome and twist counter. MapPage draws
  the track itself, north up with a scale bar. Don't use `WatchUi.MapTrackView`: on the fr970
  it crashed the app (Unexpected Type Error, no stack) and the error can't be caught.
- `source/RideDelegate.mc` — START start/pause, BACK lap, UP/DOWN/swipes page, pause menu.
  A ride is only saved or discarded from the pause menu; closing the app never saves.

Errors in sensor, GPS, switch and drawing code are caught, counted on the bottom line
("error N (see log)") and printed to `GARMIN\Apps\LOGS\TwistSwitch.TXT` (create that empty
file on the watch for println to land there).

Settings: TwistAngle (25–80°, default 35), PairTwists (default off; titled "Need a double
twist", renamed from DoubleTwist so watches with the old stored value get the new default),
ShowDebug (default on).

The simulator's Activity Data → Data Simulation feeds fake motion (it triggers twists
constantly) but no GPS position; to see the map page, build a scratch copy that preloads
points in `Track.initialize`.

## Build and run

    monkeyc -f monkey.jungle -o bin\TwistSwitch.prg -y C:\Users\dariu\developer_key -d fr970
    monkeyc -f monkey.jungle -o bin\TwistSwitchTest.prg -y C:\Users\dariu\developer_key -d fr970 -t

Sideload: copy `bin\TwistSwitch.prg` to the watch's `GARMIN\Apps`.
