# The user's commands for when things happen: what would run shows as dry lines
# in the log, by what happened. The battery is a probe's here, a file only this
# test has, put into the shell's copy.

fail() {
	echo "hooks: $1" >&2
	exit 1
}
ran() {
	log | grep -c "okaeri: dry: hook $1" || true
}
# The command for $1 was asked for once more than the $2 times before.
once_more() {
	for _ in $(seq 30); do
		[ "$(ran "$1")" -gt "$2" ] && break
		sleep 0.1
	done
	[ "$(ran "$1")" = $(($2 + 1)) ] || fail "the command for \"$1\" ran $(ran "$1") times, not $(($2 + 1))"
}
settings() {
	printf '%s\n' "$1" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	sleep 0.4
}

cat >"$work/Probe.qml" <<'QML'
import QtQuick
import Quickshell.Io
import qs.services

IpcHandler {
	target: "probe"

	function battery(charge: int, draining: bool): void {
		Power.charge = charge;
		Power.draining = draining;
	}
}
QML
sed 's/^\tHooks {}$/\tHooks {}\n\n\tProbe {}/' "$work/shell/shell.qml" >"$work/shell.qml"
grep -q 'Probe {}' "$work/shell.qml" || fail "no probe in the shell"
mv "$work/Probe.qml" "$work/shell/Probe.qml"
# In place: a file put over it isn't always seen.
cat "$work/shell.qml" >"$work/shell/shell.qml"
for _ in $(seq 50); do
	[ -z "$(ipc probe battery 100 false 2>&1)" ] && break
	sleep 0.2
done

# With no commands nothing runs, and what things are like as the shell comes up is
# no change.
sleep 2.5
[ "$(log | grep -c 'okaeri: dry: hook')" = 0 ] || fail "a command with none set: $(log | grep 'dry: hook' | tail -n 1)"

settings '{ "hooks": { "charger": "true", "battery": "true", "low": "true", "colors": "true", "wallpaper": "true" } }'
[ "$(log | grep -c 'okaeri: dry: hook')" = 0 ] || fail "a command as it's set: $(log | grep 'dry: hook' | tail -n 1)"

# The charger out and in, and a battery that gets low.
ipc probe battery 80 true
once_more battery 0
ipc probe battery 80 false
once_more charger 0
[ "$(ran low)" = 0 ] || fail "a battery that isn't low ran the command for one"
ipc probe battery 10 true
once_more low 0
once_more battery 1
ipc probe battery 100 false
once_more charger 1

# Another palette is one change, however many colors it has.
before=$(ran colors)
printf '{ "extends": "nord" }\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
once_more colors "$before"
sleep 0.6
[ "$(ran colors)" = $((before + 1)) ] || fail "a palette ran the colors' command $(($(ran colors) - before)) times"

# And another wallpaper.
settings "{ \"hooks\": { \"wallpaper\": \"true\" }, \"wallpaper\": { \"path\": \"$work/a.png\" } }"
once_more wallpaper 0

echo "hooks: all good" >&2
