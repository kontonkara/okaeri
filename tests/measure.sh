#!/bin/sh
# Runs the prototype on a headless sway pinned to the iGPU, with niri's real
# event stream, and prints its start time, memory and idle CPU, on one and
# two screens, next to the running Noctalia's. Leaves a shot in <out>. In
# the repo, with quickshell, sway and grim in PATH:
#
#   tests/measure.sh <out>
set -eu

repo=$PWD
out=${1:?usage: measure.sh <out>}
idle=${IDLE:-30}
mkdir -p "$out"

# Under the real runtime dir: a socket path has to stay short.
work=$(mktemp -d "$XDG_RUNTIME_DIR/okaeri.XXXXXX")
sway_pid=
qs_pid=

stop() {
	for pid in $qs_pid $sway_pid; do
		kill "$pid" 2>/dev/null || true
		wait "$pid" 2>/dev/null || true
	done
	qs_pid=
	sway_pid=
}
trap 'stop; rm -rf "$work"' EXIT
trap 'exit 1' INT TERM

noctalia=$(systemctl --user show -P MainPID noctalia.service)
# The real PipeWire: the bar shows its volume, and only reads it.
export PIPEWIRE_RUNTIME_DIR="$XDG_RUNTIME_DIR"

export XDG_RUNTIME_DIR="$work/run" XDG_CACHE_HOME="$work/cache" XDG_CONFIG_HOME="$work/config"
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=gles2
export WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128
export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
export QT_QPA_PLATFORM=wayland QSG_RHI_BACKEND=opengl
unset DISPLAY WAYLAND_DISPLAY SWAYSOCK
mkdir -m 700 -p "$XDG_RUNTIME_DIR"

cat >"$work/sway.conf" <<CONF
xwayland disable
output * resolution 2560x1440
CONF

memory() {
	awk -v who="$2" '
		/^Rss:/ {rss = $2}
		/^Pss:/ {pss = $2}
		/^Anonymous:/ {anon = $2}
		END {printf "%-22s rss %4d MB  pss %4d MB  anon %4d MB\n", who, rss / 1024, pss / 1024, anon / 1024}
	' "/proc/$1/smaps_rollup"
}

# The ticks a process used, user and system.
ticks() {
	sed 's/.*) //' "/proc/$1/stat" | awk '{print $12 + $13}'
}

run() {
	screens=$1
	label=$2

	WLR_HEADLESS_OUTPUTS=$screens sway --unsupported-gpu -c "$work/sway.conf" >"$work/sway.log" 2>&1 &
	sway_pid=$!
	socket=
	for _ in $(seq 100); do
		socket=$(cd "$XDG_RUNTIME_DIR" && ls wayland-* 2>/dev/null | grep -v lock | head -n 1 || true)
		[ -n "$socket" ] && break
		sleep 0.05
	done
	[ -n "$socket" ] || {
		cat "$work/sway.log" >&2
		exit 1
	}

	start=$(date +%s%3N)
	WAYLAND_DISPLAY=$socket quickshell -p "$repo/shell" >"$work/qs.log" 2>&1 &
	qs_pid=$!
	for _ in $(seq 200); do
		[ "$(grep -c 'okaeri: first frame' "$work/qs.log")" -ge "$screens" ] && break
		sleep 0.05
	done
	frame=$(sed -n 's/.*okaeri: first frame \([0-9]*\).*/\1/p' "$work/qs.log" | sort -n | tail -n 1)
	[ -n "$frame" ] || {
		cat "$work/qs.log" >&2
		exit 1
	}
	echo "$label: first frame after $((frame - start)) ms"
}

finish() {
	WAYLAND_DISPLAY=$socket grim "$out/$1.png" || true
	cp "$work/qs.log" "$out/$1.log"
	grep -iE 'warn|error|fail' "$work/qs.log" | grep -v 'first frame' | head -n 5 || true
	ls -l "/proc/$qs_pid/fd" | grep -E 'nvidia|renderD129' && echo "touched the dGPU" >&2
	stop
}

for pass in cold warm warm; do
	run 1 "1 screen, $pass cache"
	stop
done

run 1 "1 screen"
sleep 3
memory "$qs_pid" "okaeri, 1 screen"
before=$(ticks "$qs_pid")
noctalia_before=$(ticks "$noctalia")
sleep "$idle"
echo "idle over ${idle}s: okaeri $(($(ticks "$qs_pid") - before)) ticks, Noctalia $(($(ticks "$noctalia") - noctalia_before)) ticks (100 a second)"
finish one

run 2 "2 screens"
sleep 3
memory "$qs_pid" "okaeri, 2 screens"
finish two

memory "$noctalia" "Noctalia, running"
