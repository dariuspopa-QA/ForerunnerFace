# Connect IQ SDK on the HP server (Debian 13, hostname debian)
Installed 2026-10-30: OpenJDK 21 (apt), SDK 9.2.0 (same as the PC) in
`~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/` (`current-sdk.cfg` points there),
SDK Manager 1.0.16 in `~/.Garmin/sdk-manager/`. Not on PATH (call `.../bin/monkeyc` by full path).
A server-only test key `~/.Garmin/developer_key` (never printed, not the store key; store packages stay on the PC).
Missing: `~/.Garmin/ConnectIQ/Devices/` (download needs Darius's Garmin login in the SDK Manager, or copy from the
PC's `%APPDATA%\Garmin\ConnectIQ\Devices`); without it monkeyc says "Invalid device id". SDK Manager and
simulator need libwebkit2gtk-4.0 + libjpeg8, which Debian 13 no longer ships (4.1 only).
The FaceCore tools are PowerShell + System.Drawing (Windows): fonts and store shots stay on the PC.
