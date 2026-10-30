#!/bin/sh
# Headless simulator capture on Linux: builds a face's demo.jungle (else monkey.jungle) for a
# device, runs it in a simulator on a virtual display (Xvfb) inside the ciq image and saves
# the whole simulator window as PNG. Works while the desktop is locked; leaves display :1 alone.
#
#   FaceCore/tools/linux/shot.sh Bearing fr970 /tmp/bearing.png
set -e
here=$(cd "$(dirname "$0")" && pwd)
face=$(cd "$1" && pwd)
device=$2
out=$(cd "$(dirname "$3")" && pwd)/$(basename "$3")
jungle=monkey.jungle
[ -f "$face/demo.jungle" ] && jungle=demo.jungle
mkdir -p "$face/bin"
cd "$face"
"$here/ciq.sh" monkeyc -f "$jungle" -o "bin/Shot.prg" -y "$HOME/.Garmin/developer_key" -d "$device" | grep -E 'ERROR|BUILD'
docker image inspect ciq >/dev/null 2>&1 || docker build -q -t ciq "$here" >/dev/null
sdk=$(cat "$HOME/.Garmin/ConnectIQ/current-sdk.cfg")
tmp=$(mktemp -d)
up=$(dirname "$face")
docker run --rm -u "$(id -u):$(id -g)" -e HOME="$HOME" -v /etc/passwd:/etc/passwd:ro \
    -v "$HOME/.Garmin:$HOME/.Garmin" -v "$up:$up" -v "$here:$here" -v "$tmp:$tmp" -v "$(dirname "$out"):$(dirname "$out")" \
    ciq sh -c "
        Xvfb :99 -screen 0 1400x1000x24 -fbdir $tmp >/dev/null 2>&1 & sleep 2
        export DISPLAY=:99
        $sdk/bin/simulator >/dev/null 2>&1 & sleep 10
        timeout 25 $sdk/bin/monkeydo $face/bin/Shot.prg $device >/dev/null 2>&1 & sleep 15
        python3 $here/xwd2png.py $tmp/Xvfb_screen0 $out"
rm -rf "$tmp"
