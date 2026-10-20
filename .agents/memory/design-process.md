# Design process for faces
Design up front, never by small simulator tweaks (GoalBars: a long tweak run was rejected as "work in progress").
1. Study real reference faces (download images with curl, then view them).
2. Mock several full directions at the device's true resolution with the real fonts (TTFs in
   `%APPDATA%\Garmin\ConnectIQ\Fonts\`), render with headless Edge
   (`msedge --headless=new --user-data-dir=<tmp> --screenshot --window-size=454,454`), compare side by side.
3. Implement the winner, then compare a simulator capture (`FaceCore/tools/shot.ps1`) with the mock.

Taste notes: a heavy, dominant time filling the circle; empty tracks tinted with the track's own colour, not grey;
AMOLED backgrounds stay near-black (glows at most ~15-25 alpha); small per-metric icons were always rejected.
