#!/bin/sh
# Runs the bar and one part of the shell in a niri of its own, in a headless
# sway on the iGPU, on a session bus of its own, with OKAERI_DRY=1: nothing of
# the real desktop or the machine changes. A part is a directory of shell/
# and its root type; other parts aren't loaded, so one that's half done
# doesn't get in the way; with both empty it's the whole shell. Then it runs
# <script> with these at hand:
#
#   shot NAME         a picture of the screen, <out>/NAME.png
#   lane NAME         where things are on the bar in a shot
#   ipc TARGET FN ... calls the shell's IpcHandler
#   move X Y          the pointer to X Y of the 1400x900 screen
#   click [BUTTON]    left, right or middle, at the pointer
#   hold, let_go      the left button down and up, for a drag
#   wheel STEPS       the wheel, up for a positive number
#   notch NOTCHES     a mouse's wheel, which is what a list scrolls by, down for a
#                     positive number
#   swipe PIXELS      two fingers on a touchpad, down the page for a positive number
#   type TEXT         keys, and key NAME for one (Escape, Return, Tab)
#   wait_log TEXT     until the shell's log has TEXT, or fails after 5 s
#   log               the shell's log so far
#
# $NIRI_SOCKET and $WAYLAND_DISPLAY are the inner niri's. The shell's log is
# at <out>/qs.log. The shell runs from a copy, $work/shell, and reloads as a
# file there changes: write in place, it doesn't see a sed -i. It fails when
# QML complained. In the repo:
#
#   tests/tools.sh tests/part.sh <part dir> <root type> <out> <script>
set -eu

# A session bus of its own, and a process group to stop in one go.
if [ -z "${OKAERI_PART_INNER:-}" ]; then
	export OKAERI_PART_INNER=1
	exec setsid --wait dbus-run-session -- "$0" "$@"
fi

[ "$#" -eq 4 ] || {
	echo "usage: part.sh <part dir> <root type> <out> <script>" >&2
	exit 1
}
part=$1
root=$2
out=$(readlink -f "$3")
script=$(readlink -f "$4")
repo=$PWD
mkdir -p "$out"

real_run=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
work=$(mktemp -d "$real_run/okaeri.XXXXXX")

stop() {
	trap - EXIT INT TERM
	# Everything here has the unique $work in its command line or environment.
	for pid in ${hold_pid:-} ${qs_pid:-} ${niri_pid:-} ${sway_pid:-}; do
		kill "$pid" 2>/dev/null || true
	done
	sleep 0.3
	for pid in ${qs_pid:-} ${niri_pid:-} ${sway_pid:-}; do
		kill -9 "$pid" 2>/dev/null || true
		wait "$pid" 2>/dev/null || true
	done
	rm -rf "$work"
}
trap stop EXIT
trap 'exit 1' INT TERM

export PIPEWIRE_RUNTIME_DIR=$real_run
export XDG_RUNTIME_DIR=$work/run XDG_CACHE_HOME=$work/cache XDG_CONFIG_HOME=$work/config XDG_STATE_HOME=$work/state
export OKAERI_DRY=1 QT_QPA_PLATFORM=wayland QSG_RHI_BACKEND=opengl QT_NO_XDG_DESKTOP_PORTAL=1
# As bin/okaeri has it.
export mesa_glthread=false GALLIUM_THREAD=0
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=gles2 WLR_HEADLESS_OUTPUTS=1
export WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128
export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
unset DISPLAY WAYLAND_DISPLAY SWAYSOCK NIRI_SOCKET
mkdir -m 700 -p "$XDG_RUNTIME_DIR"
mkdir -p "$XDG_CONFIG_HOME/okaeri" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

# The shell as it is, with only this part in it, if it's a part.
cp -r "$repo/shell" "$work/shell"
# What failed here is what a test puts in $work/failed-system and failed-user,
# not what failed on the machine.
cat >"$work/systemctl" <<SH
#!/bin/sh
[ "\$1" = --user ] && scope=user || scope=system
cat "$work/failed-\$scope" 2>/dev/null || echo '[]'
SH
chmod +x "$work/systemctl"
sed -i "s|\"systemctl\"|\"$work/systemctl\"|" "$work/shell/services/Units.qml"
# The lights here are files a test can write to, not the keyboard's.
mkdir -p "$work/leds/input9::capslock" "$work/leds/input9::numlock"
echo 0 >"$work/leds/input9::capslock/brightness"
echo 0 >"$work/leds/input9::numlock/brightness"
sed -i "s|/sys/class/leds|$work/leds|g" "$work/shell/services/Locks.qml"
# So do the machine's outputs: a test that wants some puts its own.
sed -i 's/^\treadonly property var outputs: .*/\tproperty var outputs: []/' "$work/shell/services/Audio.qml"
# The machine's battery could run low under a test: here it's what a test says.
sed -i -e 's/^\treadonly property int charge: .*/\tproperty int charge: 100/' \
	-e 's/^\treadonly property bool draining: .*/\tproperty bool draining: false/' "$work/shell/services/Power.qml"
# What the machine plays comes and goes, and would move the whole shell's shots.
[ -n "$part" ] || sed -i 's/^\treadonly property var nodes: .*/\treadonly property var nodes: []/' "$work/shell/services/Audio.qml"
[ -z "$part" ] || cat >"$work/shell/shell.qml" <<QML
import QtQuick
import Quickshell
import qs.bar
import qs.$part

ShellRoot {
	Variants {
		model: Quickshell.screens

		Bar {
			required property var modelData

			screen: modelData
		}
	}

	$root {}
}
QML

printf 'xwayland disable\noutput * resolution 1400x900\ndefault_border none\n' >"$work/sway.conf"
sway --unsupported-gpu -c "$work/sway.conf" >"$work/sway.log" 2>&1 &
sway_pid=$!

socket() {
	(cd "$XDG_RUNTIME_DIR" && ls wayland-* 2>/dev/null | grep -v lock | sort | sed -n "$1p") || true
}
for _ in $(seq 100); do
	outer=$(socket 1)
	[ -n "$outer" ] && break
	sleep 0.05
done
[ -n "$outer" ] || {
	cat "$work/sway.log" >&2
	exit 1
}

cat >"$work/niri.kdl" <<'KDL'
workspace "one"
workspace "two"
workspace "three"
hotkey-overlay {
	skip-at-startup
}
gestures {
	hot-corners {
		off
	}
}
prefer-no-csd
KDL
printf 'screenshot-path "%s/shots/%%s.png"\n' "$work" >>"$work/niri.kdl"
printf 'include optional=true "%s/okaeri/niri.kdl"\n' "$XDG_STATE_HOME" >>"$work/niri.kdl"
WAYLAND_DISPLAY=$outer niri -c "$work/niri.kdl" >"$work/niri.log" 2>&1 &
niri_pid=$!
for _ in $(seq 100); do
	NIRI_SOCKET=$(ls "$XDG_RUNTIME_DIR"/niri.*.sock 2>/dev/null | head -n 1 || true)
	inner=$(socket 2)
	[ -n "$NIRI_SOCKET" ] && [ -n "$inner" ] && break
	sleep 0.1
done
[ -n "${NIRI_SOCKET:-}" ] || {
	cat "$work/niri.log" >&2
	exit 1
}
export NIRI_SOCKET
export WAYLAND_DISPLAY=$inner

quickshell -p "$work/shell" >"$out/qs.log" 2>&1 &
qs_pid=$!
for _ in $(seq 100); do
	grep -q 'okaeri: first frame' "$out/qs.log" && break
	sleep 0.1
done
sleep 0.5

shot() {
	WAYLAND_DISPLAY=$outer grim "$out/$1.png"
}
# Right after a reload it says it's not ready yet, and exits 0 all the same.
ipc() {
	for _ in $(seq 100); do
		answer=$(quickshell ipc -p "$work/shell" call -- "$@") || return
		case $answer in
		"Not ready"*) sleep 0.1 ;;
		*)
			[ -z "$answer" ] || printf '%s\n' "$answer"
			return 0
			;;
		esac
	done
	echo "part.sh: the shell takes no calls" >&2
	return 1
}
# The middles of what's on the bar right of the clock in shot NAME, from the
# left: the bell, the clipboard, and on to the control center. An app in the
# tray would come first, and the stand's bus has one only if a test puts it
# there. In the dark theme.
lane() {
	magick "$out/$1.png" -crop 548x18+840+12 +repage -colorspace Gray -scale 548x1! txt:- |
		awk -F'[,:]' -v from=840 '
			NR == 1 { next }
			/gray\(0\)|#000000/ { gap++; next }
			{
				if (gap > 8 && last) {
					print int((first + last) / 2) + from
					first = 0
				}
				if (!first)
					first = $1 + 0
				last = $1 + 0
				gap = 0
			}
			END { if (last) print int((first + last) / 2) + from }
		'
}
# Where the pointer is isn't known at first: into the corner, then from there.
move() {
	wlrctl pointer move -3000 -3000
	wlrctl pointer move "$1" "$2"
	sleep 0.1
}
click() {
	wlrctl pointer click "${1:-left}"
	sleep 0.2
}
hold() {
	python3 "$repo/tests/hold.py" &
	hold_pid=$!
	sleep 0.3
}
let_go() {
	kill "$hold_pid"
	wait "$hold_pid"
	sleep 0.2
}
wheel() {
	wlrctl pointer scroll "$((-15 * $1))" 0
	sleep 0.2
}
notch() {
	python3 "$repo/tests/hold.py" notch "$1"
}
swipe() {
	python3 "$repo/tests/hold.py" swipe "$1"
}
type() {
	wtype -- "$1"
	sleep 0.2
}
key() {
	wtype -k "$1"
	sleep 0.2
}
log() {
	sed 's/\x1b\[[0-9;]*m//g' "$out/qs.log"
}
wait_log() {
	for _ in $(seq 50); do
		log | grep -qF "$1" && return 0
		sleep 0.1
	done
	echo "part.sh: no \"$1\" in the log" >&2
	return 1
}

. "$script"

# What QML had to say, without Qt's own noise.
if log | grep -E 'WARN|ERROR' | grep -vE 'host portal|textinput|Could not load icon' | grep -E 'qml|\.qml|TypeError|ReferenceError|destroyed'; then
	echo "part.sh: QML complained" >&2
	exit 1
fi
