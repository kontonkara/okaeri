# Idling, with seconds for minutes. What it'd do shows as dry lines in the log.

fail() {
	echo "idle: $1" >&2
	exit 1
}

lines() {
	log | sed -n 's/.*okaeri: dry: //p'
}
seen=0
# The next dry line is $1, and the only one, within $2 tenths of a second.
said() {
	seen=$((seen + 1))
	for _ in $(seq "$2"); do
		[ "$(lines | wc -l)" -ge "$seen" ] && break
		sleep 0.1
	done
	got=$(lines | sed -n "${seen}p")
	[ "$got" = "$1" ] || fail "wanted \"$1\", got \"$got\""
	[ "$(lines | wc -l)" -eq "$seen" ] || fail "more than \"$1\": $(lines | tail -n 1)"
}
silent() {
	[ "$(lines | wc -l)" -eq "$seen" ] || fail "$1: $(lines | tail -n 1)"
}
fades() {
	niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-fade")] | length'
}
wait_fades() {
	for _ in $(seq "$2"); do
		[ "$(fades)" = "$1" ] && return 0
		sleep 0.1
	done
	fail "$3: $(fades) fades up, not $1"
}
wake() {
	wlrctl pointer move 5 5
	sleep 0.2
	wlrctl pointer move -5 -5
	sleep 0.2
}
settings() {
	printf '%s\n' "$1" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	sleep 0.4
}

# Out of the box nothing happens in a test's time.
sleep 2
silent "the defaults"
[ "$(fades)" = 0 ] || fail "a fade at the start"

# Fade, lock, fade, screens off, in that order.
settings '{ "idle": { "lock": 3, "screenOff": 6, "fade": 1 } }'
wake
wait_fades 1 30 "before the lock"
sleep 0.5
shot fading
silent "the lock came with its fade"
said "session lock" 20
wait_fades 0 10 "after the lock"
wait_fades 1 30 "before the screens go off"
said "screens off" 20
wait_fades 0 10 "after the screens went off"

# Coming back in the fade takes it all back.
wake
wait_fades 0 5 "after waking"
wait_fades 1 30 "before the lock, again"
wake
wait_fades 0 5 "waking in the fade"
sleep 1.5
silent "waking in the fade"
wake

# Awake holds it off.
ipc awake toggle
sleep 7
silent "while awake"
[ "$(fades)" = 0 ] || fail "a fade while awake"
ipc awake toggle
wake

# For a while, and then it's idling again.
ipc awake forSeconds 2
sleep 3.4
silent "while awake for a while"
wake
wait_fades 1 40 "after keeping awake ended"
wake

# 0 is never.
settings '{ "idle": { "lock": 0, "screenOff": 0, "fade": 1 } }'
wake
sleep 4
silent "with both off"
[ "$(fades)" = 0 ] || fail "a fade with both off"

# Without a fade, straight to it.
settings '{ "idle": { "lock": 2, "screenOff": 0, "fade": 0 } }'
wake
sleep 1.5
[ "$(fades)" = 0 ] || fail "a fade without one"
said "session lock" 20


# Sleep, after the rest; only on battery, it waits for the charger to come out,
# which a probe says here.
settings '{ "idle": { "lock": 0, "screenOff": 0, "suspend": 2, "suspendOn": "battery" } }'
wake
cat >"$work/Probe.qml" <<'QML'
import QtQuick
import Quickshell.Io
import qs.services

IpcHandler {
	target: "probe"

	function draining(on: bool): void {
		Power.draining = on;
	}
}
QML
sed 's/^\tIdle {}$/\tIdle {}\n\n\tProbe {}/' "$work/shell/shell.qml" >"$work/shell.qml"
grep -q 'Probe {}' "$work/shell.qml" || fail "no probe in the shell"
mv "$work/Probe.qml" "$work/shell/Probe.qml"
# In place: a file put over it isn't always seen.
cat "$work/shell.qml" >"$work/shell/shell.qml"
# Until it answers.
for _ in $(seq 50); do
	[ -z "$(ipc probe draining false 2>&1)" ] && break
	sleep 0.2
done
sleep 0.5
sleep 3
silent "sleep on battery, on the charger"
ipc probe draining true
said "session suspend" 10
ipc probe draining false
wake
settings '{ "idle": { "lock": 0, "screenOff": 0, "suspend": 2 } }'
wake
sleep 1.5
said "session suspend" 20

# Not while something plays, a player on this bus with nothing to hear: once it's
# gone, the machine sleeps after all.
mpv --no-config --no-terminal --ao=null --vo=null --loop-playlist=inf --script="$OKAERI_MPV_MPRIS" av://lavfi:sine >/dev/null 2>&1 &
player=$!
sleep 2
wake
sleep 4
silent "sleep with something playing"
kill "$player"
wait "$player" 2>/dev/null || true
said "session suspend" 20

echo "idle: all good" >&2
