# Connect IQ SDK on the HP server (Debian 13, hostname debian, 192.168.0.117)
Works (2026-10-30): build, simulator, unit tests and captures. Terrain: 41/41 tests pass on fr970.
- SDK 9.2.0 (same as the PC) in `~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/`,
  `current-sdk.cfg` points there; SDK Manager 1.0.16 in `~/.Garmin/sdk-manager/`; Devices and Fonts copied from the
  PC's `%APPDATA%\Garmin\ConnectIQ\` (scp from cmd: `%APPDATA%`, not `$env:APPDATA`).
- Debian 13 lacks webkit2gtk-4.0 / libjpeg8 / libcurl4: run every tool through `FaceCore/tools/linux/ciq.sh`
  (Ubuntu 22.04 docker image `ciq`). The container needs /etc/passwd mounted (else Java has no home and monkeyc says
  "Invalid device id") and ~/.Xauthority for display :1. monkeyc doesn't follow a symlinked ../FaceCore.
- The desktop on :1 is often locked: the simulator window then stays blank. `FaceCore/tools/linux/shot.sh` runs the
  simulator under Xvfb instead.
- Server-only test key `~/.Garmin/developer_key` (never printed, not the store key; store packages stay on the PC).
- FaceCore PowerShell tools need System.Drawing (Windows): fonts and store shots stay on the PC.
