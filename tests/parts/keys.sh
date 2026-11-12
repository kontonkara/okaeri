# What the keyboard's keys call. What they'd change shows as dry lines in the
# log. The volume, the microphone and the brightness are the machine's, and only
# read; the players are real ones on the stand's bus, with nothing to see or hear.

mpv_pids=

fail() {
	echo "keys: $1" >&2
	# shellcheck disable=SC2086
	[ -z "$mpv_pids" ] || kill $mpv_pids
	exit 1
}

# What was done: a sound goes with it, and has a check of its own.
lines() {
	log | sed -n 's/.*okaeri: dry: //p' | grep -v 'sound ' || true
}
# The next dry line starts with $1, and it's the only one.
seen=0
said() {
	seen=$((seen + 1))
	for _ in $(seq 30); do
		[ "$(lines | wc -l)" -ge "$seen" ] && break
		sleep 0.1
	done
	got=$(lines | sed -n "${seen}p")
	case $got in
	"$1"*) ;;
	*) fail "wanted \"$1\", got \"$got\"" ;;
	esac
	[ "$(lines | wc -l)" -eq "$seen" ] || fail "more than \"$1\": $(lines | tail -n 1)"
}
silent() {
	sleep 0.4
	[ "$(lines | wc -l)" -eq "$seen" ] || fail "$1: $(lines | tail -n 1)"
}

# A service comes up with the first call to it, and takes its time: until one
# gets through.
reach() {
	for _ in $(seq 50); do
		ipc "$@"
		sleep 0.2
		[ "$(lines | wc -l)" = "$seen" ] || break
	done
	seen=$(lines | wc -l)
}
reach volume up 10

ipc volume up 10
# Up is to be heard: on a machine that's muted, the mute comes off first.
! wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED || seen=$((seen + 1))
said "volume "
up=$got
ipc volume down 10
said "volume "
down=$got
[ "${up#volume }" != "${down#volume }" ] || fail "up and down are both $up"
awk -v u="${up#volume }" -v d="${down#volume }" 'BEGIN { exit !(u > d) }' || fail "$up isn't over $down"
wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED || log | grep -q 'dry: sound audio-volume-change' || fail "a change of the volume has no sound"
# Or to a level at once, for a script: from the machine's, which a dry run
# leaves as it is.
ipc volume set 40
sleep 0.5
got=$(lines | grep '^volume ' | tail -n 1)
seen=$(lines | wc -l)
awk -v v="${got#volume }" 'BEGIN { exit !(v > 0.39 && v < 0.41) }' || fail "the volume set to 40 is $got"
ipc volume mute
said "mute "

# A machine can well have no microphone, and then there's nothing to mute.
ipc mic mute
if wpctl inspect @DEFAULT_AUDIO_SOURCE@ >/dev/null 2>&1; then
	said "mic mute "
	ipc mic up 10
	said "mic volume "
	up=$got
	ipc mic down 10
	said "mic volume "
	awk -v u="${up#mic volume }" -v d="${got#mic volume }" 'BEGIN { exit !(u > d) }' || fail "$up isn't over $got"
	ipc mic set 40
	said "mic volume "
	awk -v v="${got#mic volume }" 'BEGIN { exit !(v > 0.39 && v < 0.41) }' || fail "the microphone set to 40 is $got"
else
	silent "a microphone out of nowhere"
fi

reach brightness up 10
ipc brightness up 10
said "brightness "
up=$got
ipc brightness down 10
said "brightness "
[ "${up#brightness }" -gt "${got#brightness }" ] || fail "$up isn't over $got"
ipc brightness set 70
said "brightness "
high=$got
ipc brightness set 30
said "brightness "
[ "${high#brightness }" -gt "${got#brightness }" ] || fail "the brightness set to 70, $high, isn't over 30, $got"

# With DDC on, the keys are the screen's in focus where that's an external one:
# here the stand's own, made to look like one, at 40 of 100.
screen=$(niri msg --json outputs | jq -r 'keys[0]')
mkdir -p "$work/drm/card1/device/power" "$work/drm/card1-$screen"
echo connected >"$work/drm/card1-$screen/status"
ln -s "../../i2c-7" "$work/drm/card1-$screen/ddc"
echo active >"$work/drm/card1/device/power/runtime_status"
printf '{ "display": { "ddc": true } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
for _ in $(seq 30); do
	grep -q 'getvcp' "$work/ddcutil.log" 2>/dev/null && break
	sleep 0.1
done
sleep 0.3
ipc brightness up 10
said "ddc $screen 50"
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
rm -r "$work/drm/card1" "$work/drm/card1-$screen"
sleep 0.5

# No player, nothing to tell.
ipc media toggle
ipc media stop
ipc media next
ipc media previous
silent "with no player"

# The name that pid's mpv has on the bus.
named() {
	dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
		org.freedesktop.DBus.ListNames | sed -n 's/.*"\(org\.mpris\.MediaPlayer2\.mpv[^"]*\)"/\1/p' | grep -v -xF "$1"
}
player() {
	mpv --no-config --no-terminal --ao=null --vo=null --loop-playlist=inf \
		--script="$OKAERI_MPV_MPRIS" "$@" av://lavfi:sine av://lavfi:sine >/dev/null 2>&1 &
	mpv_pids="$mpv_pids $!"
	pid=$!
}
wait_name() {
	for _ in $(seq 100); do
		name=$(named "$1" || true)
		[ -n "$name" ] && return 0
		sleep 0.1
	done
	fail "no mpv on the bus"
}
# Until the shell has seen what just changed.
settle() {
	sleep 0.6
}

player --pause
first=$pid
wait_name "nothing"
first_name=$name
settle
ipc media toggle
said "media toggle $first_name"

player
second=$pid
wait_name "$first_name"
second_name=$name
settle
ipc media toggle
said "media toggle $second_name"
ipc media next
said "media next $second_name"
ipc media previous
said "media previous $second_name"
ipc media stop
said "media stop $second_name"
ipc media forward 10
said "media seek $second_name by 10"
ipc media back 10
said "media seek $second_name by -10"
# The next player along holds while the other plays, and then it's back.
ipc media cycle
ipc media toggle
said "media toggle $first_name"
ipc media cycle
ipc media toggle
said "media toggle $second_name"

# The last that played, though it's not the first there is, and none plays.
dbus-send --session --dest="$second_name" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Pause
settle
ipc media toggle
said "media toggle $second_name"

# It goes, and the other is left.
kill "$second"
wait "$second" 2>/dev/null || true
settle
ipc media toggle
said "media toggle $first_name"

kill "$first"
wait "$first" 2>/dev/null || true
mpv_pids=
settle
ipc media toggle
silent "after the players went"

# A recording of the screen is asked for as the settings have it, and with none
# running there's none to stop.
ipc record stop
silent "a stop with nothing recorded"
ipc record start
said "record start screen none"
printf '{ "recording": { "audio": "system" } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.5
ipc record toggle
said "record start screen system"
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.5

# A keyboard that lights up, which this stand has only from here: the shell finds
# it as it starts again. Three steps of light, one of them on.
mkdir "$work/leds/platform::kbd_backlight"
echo 1 >"$work/leds/platform::kbd_backlight/brightness"
echo 3 >"$work/leds/platform::kbd_backlight/max_brightness"
loads=$(log | grep -c "Configuration Loaded")
printf '\n// Once more.\n' >>"$work/shell/keys/Keys.qml"
for _ in $(seq 50); do
	[ "$(log | grep -c "Configuration Loaded")" -gt "$loads" ] && break
	sleep 0.1
done
sleep 0.5
reach keylight up 30
[ "$(lines | tail -n 1)" = "keyboard light 2" ] || fail "the keyboard's light up: $(lines | tail -n 1)"
ipc keylight down 30
said "keyboard light 0"
ipc keylight set 100
said "keyboard light 3"

# The bar hides, or stays, as its setting then says.
hides() {
	jq -c .bar.autoHide "$XDG_STATE_HOME/okaeri/settings.json"
}
ipc bar hide
sleep 0.3
[ "$(hides)" = true ] || fail "the bar doesn't hide: $(hides)"
ipc bar toggle
sleep 0.3
[ "$(hides)" = false ] || fail "the bar doesn't stay: $(hides)"
ipc bar toggle
ipc bar show
sleep 0.3
[ "$(hides)" = false ] || fail "the bar isn't back: $(hides)"

echo "keys: all good" >&2
