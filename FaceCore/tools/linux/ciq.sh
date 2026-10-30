#!/bin/sh
# Runs a Connect IQ tool in the ciq image (Dockerfile here) with ~/.Garmin, the repo and the
# desktop display. Builds the image on first use.
#
#   FaceCore/tools/linux/ciq.sh sdkmanager                 # log in, download devices (GUI)
#   FaceCore/tools/linux/ciq.sh simulator &                # the simulator (GUI)
#   FaceCore/tools/linux/ciq.sh monkeyc -f monkey.jungle -o bin/X.prg -y ~/.Garmin/developer_key -d fr970
#   FaceCore/tools/linux/ciq.sh monkeydo bin/Test.prg fr970 -t
#
# The container shares the host network, so monkeydo reaches a simulator started by ciq.sh.
set -e
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
docker image inspect ciq >/dev/null 2>&1 || docker build -q -t ciq "$here" >/dev/null
sdk=$(cat "$HOME/.Garmin/ConnectIQ/current-sdk.cfg")
tool=$1
shift
case "$tool" in
    sdkmanager) cmd="$HOME/.Garmin/sdk-manager/bin/sdkmanager" ;;
    *) cmd="$sdk/bin/$tool" ;;
esac
xauth=${XAUTHORITY:-$HOME/.Xauthority}
x11=""
[ -f "$xauth" ] && x11="-v $xauth:/tmp/.ciq-xauth:ro -e XAUTHORITY=/tmp/.ciq-xauth"
# The working folder's parent too (a face copy next to its ../FaceCore) when outside the repo
work=""
case "$PWD" in "$repo"|"$repo"/*) ;; *) up=$(dirname "$PWD"); work="-v $up:$up" ;; esac
tty=""
[ -t 0 ] && tty="-it"
exec docker run --rm $tty --network host --ipc host \
    -u "$(id -u):$(id -g)" -e HOME="$HOME" -e DISPLAY="${DISPLAY:-:1}" $x11 \
    -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro -v /tmp/.X11-unix:/tmp/.X11-unix -v "$HOME/.Garmin:$HOME/.Garmin" -v "$repo:$repo" $work \
    -w "$PWD" ciq "$cmd" "$@"
