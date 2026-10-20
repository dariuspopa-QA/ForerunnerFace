# Sideloading to the watch
Watches mount over MTP (no drive letter): copy with PowerShell `Shell.Application` to
`This PC > <watch> > Internal Storage > GARMIN > Apps`. `CopyHere` silently keeps an existing .prg, so delete the
old file first, then copy and compare sizes. Skill: `.agents/skills/push-to-watch`. Only on Darius's go-ahead.
Toolchain: Connect IQ SDK 9.2 under `%APPDATA%\Garmin\ConnectIQ\Sdks\`; developer key at `C:\Users\dariu\developer_key`
(never committed, never printed).
