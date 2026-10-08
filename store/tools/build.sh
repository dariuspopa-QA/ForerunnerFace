#!/bin/sh
# build.sh NAME AOD ACCENT NUMERALS F1 F2 F3 ARC HOUR MIN SEC
cd "$(dirname "$0")"
cat > source/ShotConfig.mc <<MC
import Toybox.Lang;
module ShotConfig {
    const AOD = $2;
    const ACCENT = $3;
    const NUMERALS = $4;
    const FIELDS = [$5, $6, $7] as Array<Number>;
    const ARC = $8;
    const HOUR = $9;
    const MIN = ${10};
    const SEC = ${11};
}
MC
SDK="$APPDATA/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"
"$SDK/bin/monkeyc.bat" -f monkey.jungle -d fr970 -o "bin/$1.prg" -y "C:/Users/dariu/developer_key" -l 3 2>&1 | tail -5
