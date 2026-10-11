# Minimal Face

Minimal, configurable AMOLED watch face for Garmin Forerunner 265, 265S and 970.

## Build
1. Install the Connect IQ SDK and the VS Code "Monkey C" extension.
2. Open this folder in VS Code.
3. Run "Monkey C: Build for Device" and choose fr265 (or fr265s / fr970).
4. Copy the resulting .prg to the watch's GARMIN/APPS folder over USB.

To test settings in the simulator: File > Edit Persistent Storage > Edit Application.Properties.

## Settings (Garmin Connect app > Watch faces > Minimal Face > Settings)
- Accent color, clock format, time weight, date format
- Ring: steps / battery / off
- Left and right field: heart rate, battery, steps, calories
- Show/hide: notifications, missed calls, alarms, do not disturb
- Date in always-on mode

## Missed calls
Connect IQ has no missed-call API. This face listens for a phone app message
{ "missedCalls": n } sent by an Android companion app using the Connect IQ
Mobile SDK. Without that app, leave "Show missed calls" off.

## Layout
All positions are fractions of the screen radius, defined at the top of
source/FaceView.mc (Y_STATUS, Y_DATE, ...). Adjust them there.
