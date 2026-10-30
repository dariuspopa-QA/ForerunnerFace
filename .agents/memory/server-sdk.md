# Connect IQ SDK on the HP server (Debian 13, hostname debian, 192.168.0.117)
Installed 2026-10-30: SDK 9.2.0 (same as the PC) in `~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/`
(`current-sdk.cfg` points there), SDK Manager 1.0.16 in `~/.Garmin/sdk-manager/`, OpenJDK 21 on the host.
Debian 13 lacks webkit2gtk-4.0 / libjpeg8 / matching libcurl, so run every tool through
`FaceCore/tools/linux/ciq.sh` (Ubuntu 22.04 docker image `ciq`, all libraries present, display :1).
A server-only test key `~/.Garmin/developer_key` (never printed, not the store key; store packages stay on the PC).
Devices: copied from the PC's `%APPDATA%\Garmin\ConnectIQ\Devices` to `~/.Garmin/ConnectIQ/Devices/` (Darius's
choice over logging in to the SDK Manager); without them monkeyc says "Invalid device id".
The FaceCore PowerShell tools need System.Drawing (Windows): fonts and store shots stay on the PC.
