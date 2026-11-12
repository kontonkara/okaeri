# The OSD. By IPC: it shows, in the right place, for a moment, and repeats
# update it in place. Under it, a real window: clicks and keys reach that, and
# it keeps its size. Real values can't be changed here and the machine's can
# move on their own, so past the startup it all runs on a stand-in Audio and
# Brightness, in the stand's copy of the shell, which reloads as it's written.

# The card is 256x50 at scale 1, 48 up from the bottom edge, in the middle;
# the track runs along y 827 from x 614, 200 long.
left=572 right=828 top=802 bottom=852 middle=827 track=614

fail() {
	echo "osd: $*" >&2
	exit 1
}
now() {
	date +%s%3N
}
up() {
	niri msg --json layers | jq -e 'any(.[]; .namespace == "okaeri-osd")' >/dev/null
}
show() {
	ipc osd show "$@"
}
stays_off() {
	end=$(($(now) + $1))
	while [ "$(now)" -lt "$end" ]; do
		! up || fail "$2"
		sleep 0.05
	done
}
comes_up() {
	end=$(($(now) + 1000))
	until up; do
		[ "$(now)" -lt "$end" ] || fail "$1"
		sleep 0.02
	done
}
# How long, from `since`, until it's gone.
leaves() {
	while up; do
		[ $(($(now) - $1)) -lt 4000 ] || fail "it never left"
		sleep 0.02
	done
	echo $(($(now) - $1))
}
between() {
	[ "$2" -ge "$3" ] && [ "$2" -le "$4" ] || fail "$1: $2, not $3 to $4"
}
pixel() {
	magick "$out/$1.png" -depth 8 -format "%[hex:p{$2,$3}]" info: | cut -c1-6 | tr 'A-F' 'a-f'
}
same() {
	[ "$2" = "$3" ] || fail "$1: $2, not $3"
}
# How much of the track is in `color`, in pixels.
filled() {
	magick "$out/$1.png" -depth 8 -crop "200x1+$track+$middle" +repage txt:- | grep -ci "#$2" || true
}
# What the icon looks like, to tell one from another.
icon() {
	magick "$out/$1.png" -crop "24x24+$((left + 12))+$((middle - 12))" +repage -format '%#' info:
}
# The first and the last pixel of a row that aren't the desk: a card's edges.
edges() {
	magick "$out/$1.png" -depth 8 -crop "1400x1+0+$2" +repage txt:- | grep -vi "#$desk" | sed -n '2p;$p' | grep -o '#[0-9A-Fa-f]\{6\}'
}
theme() {
	printf '%s' "$1" >"$XDG_CONFIG_HOME/okaeri/theme.json"
	sleep 0.4
}
# What a shot of the card has to say: where it is and what's filled.
card() {
	same "$1: inside" "$(pixel "$1" $((left + 6)) $((top + 6)))" "$2"
	same "$1: left of it" "$(pixel "$1" $((left - 8)) $middle)" "$desk"
	same "$1: right of it" "$(pixel "$1" $((right + 8)) $middle)" "$desk"
	same "$1: above it" "$(pixel "$1" 700 $((top - 8)))" "$desk"
	same "$1: below it" "$(pixel "$1" 700 $((bottom + 8)))" "$desk"
	between "$1: filled" "$(filled "$1" "$3")" $(($4 - 3)) $(($4 + 3))
}

# Real Audio and Brightness come up as it starts: that isn't a change. The
# stand waits half a second, so a card would still be there.
stays_off 2000 "it showed at startup"
shot nothing
desk=$(pixel nothing 700 $middle)
same "nothing left of the middle" "$(pixel nothing $((left + 6)) $middle)" "$desk"

# From here on the machine stays out: its volume or brightness moving would
# rightly bring a card of its own, over the one under test. A stand-in Audio
# and Brightness, a way to poke them, and a real window to be under, hidden
# until it's needed.
cat >"$work/Audio.qml" <<'QML'
pragma Singleton

import QtQuick
import Quickshell

Singleton {
	property real limit: 1
	property var sink: "first"
	property bool ready: false
	property real volume: 0
	property bool muted: false
	property var source: "first"
	property bool micReady: true
	property real micVolume: 0.6
	property bool micMuted: false

	signal stayed
	signal micStayed

	function change(by) {}
	function toggleMute() {}
	function toggleMicMute() {}
}
QML
cat >"$work/Brightness.qml" <<'QML'
pragma Singleton

import QtQuick
import Quickshell

Singleton {
	property string device: "first"
	property bool available: true
	property real level: 0.25

	signal stayed

	function change(by) {}
}
QML
cat >"$work/shell.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.bar
import qs.osd
import qs.services

ShellRoot {
	Variants {
		model: Quickshell.screens

		Bar {
			required property var modelData

			screen: modelData
		}
	}

	Osd {}

	IpcHandler {
		target: "poke"

		// The value first: `ready` may well come after it.
		function audio(ready: bool, volume: real, muted: bool): void {
			Audio.volume = volume;
			Audio.muted = muted;
			Audio.ready = ready;
		}

		function sink(volume: real): void {
			Audio.volume = volume;
			Audio.sink = "second";
		}

		function mic(muted: bool): void {
			Audio.micMuted = muted;
		}

		function micVolume(volume: real): void {
			Audio.micVolume = volume;
		}

		function limit(limit: real): void {
			Audio.limit = limit;
		}

		// A key at an end of the volume, or of the brightness.
		function stay(what: string): void {
			if (what === "volume")
				Audio.stayed();
			else
				Brightness.stayed();
		}

		function brightness(level: real): void {
			Brightness.level = level;
		}

		function under(): void {
			window.visible = true;
		}

		function ready(): void {}
	}

	FloatingWindow {
		id: window

		visible: false
		title: "under"
		color: Theme.colors.surface

		MouseArea {
			property int clicks: 0

			anchors.fill: parent
			onClicked: console.info(`okaeri: under: click ${++clicks}`)
		}

		Item {
			focus: true
			Keys.onPressed: event => console.info(`okaeri: under: key ${event.text}`)
			Component.onCompleted: console.info("okaeri: under: here")
		}
	}
}
QML
# In whole, and the root last: a reload mustn't find them half written.
mv "$work/Audio.qml" "$work/shell/services/Audio.qml"
mv "$work/Brightness.qml" "$work/shell/services/Brightness.qml"
mv "$work/shell.qml" "$work/shell/shell.qml"
wait_log "okaeri: under: here"

# Nothing at a reload, nor before the service is there.
stays_off 1300 "it showed at a reload"

# It's an overlay, without the keyboard.
show volume 0.4
since=$(now)
comes_up "no card on a call"
niri msg --json layers | jq -e 'any(.[]; .namespace == "okaeri-osd" and .layer == "Overlay" and .keyboard_interactivity == "None")' >/dev/null ||
	fail "not an overlay without the keyboard"
sleep 0.4
shot volume-dark
card volume-dark 000000 ffffff 80

# It leaves on its own, about 1.5 s on, and nothing is left behind.
between "left after" "$(leaves "$since")" 1450 2300
sleep 0.1
shot gone
same "where it was" "$(pixel gone $((left + 6)) $middle)" "$desk"

# The microphone, as it's muted and back.
ipc poke mic true
comes_up "no card for the muted microphone"
sleep 0.4
shot mic-muted
ipc poke mic false
sleep 0.4
shot mic
leaves "$(now)" >/dev/null

show mute 0.7
sleep 0.4
shot mute-dark
# Dimmed: the fill at the slider's 0.5, over the track.
card mute-dark 000000 898989 140
leaves "$(now)" >/dev/null

show brightness 0.25
sleep 0.4
shot brightness-dark
card brightness-dark 000000 ffffff 50
leaves "$(now)" >/dev/null

[ "$(icon volume-dark)" != "$(icon mute-dark)" ] || fail "volume and mute have the same icon"
[ "$(icon volume-dark)" != "$(icon brightness-dark)" ] || fail "volume and brightness have the same icon"

# Both ends: past 1, as a volume can be, it's full; at 0 it's still a dot.
show volume 1.3
sleep 0.4
shot full
card full 000000 ffffff 200
show volume 0
sleep 0.4
shot empty
card empty 000000 ffffff 5
leaves "$(now)" >/dev/null

# What it doesn't know it says so, and doesn't show. That's also what every
# JS object has by way of its prototype.
for kind in nonsense toString constructor __proto__; do
	show "$kind" 0.5
	wait_log "no osd \"$kind\""
	stays_off 400 "it showed \"$kind\", which is no kind"
done

# Quick repeats: it stays, in the same place, at full strength, and the time
# runs from the last one. Longer in all than one showing.
for step in 2 3 4 5 6 7; do
	show volume "0.$step"
	since=$(now)
	sleep 0.3
	up || fail "gone between repeats"
	shot "repeat-$step"
	card "repeat-$step" 000000 ffffff $((step * 20))
	up || fail "gone between repeats"
done
between "left after the last repeat" "$(leaves "$since")" 1450 2300

# A call right as it starts to fade brings it back.
show volume 0.5
sleep 1.55
show volume 0.6
since=$(now)
sleep 1.2
up || fail "it left despite a call during the fade"
sleep 0.1
shot back
card back 000000 ffffff 120
between "left after the fade's call" "$(leaves "$since")" 1450 2300

# A key at an end of the volume or of the brightness moves neither, and still
# gets its card.
ipc poke stay volume
comes_up "no card for a volume key at its end"
leaves "$(now)" >/dev/null
ipc poke stay brightness
comes_up "no card for a brightness key at its end"
leaves "$(now)" >/dev/null

# Each theme by its own colors.
theme '{"extends":"light"}'
show volume 0.4
sleep 0.4
shot volume-light
card volume-light ffffff 111111 80
leaves "$(now)" >/dev/null
show mute 0.7
sleep 0.4
shot mute-light
card mute-light ffffff 7f7f7f 140
leaves "$(now)" >/dev/null
show brightness 0.25
sleep 0.4
shot brightness-light
card brightness-light ffffff 111111 50
leaves "$(now)" >/dev/null

# Without animations it's there and gone at once. Square corners and a bigger
# scale go by the theme too.
theme '{"animations":false}'
show volume 0.4
since=$(now)
shot unanimated
card unanimated 000000 ffffff 80
between "left without animations" "$(leaves "$since")" 1450 1800

theme '{"radius":0,"scale":1.5}'
show brightness 0.5
sleep 0.4
shot square-big
same "bigger: inside" "$(pixel square-big 700 $((900 - 72 - 8)))" 000000
same "bigger: square corner" "$(pixel square-big $((700 - 192 + 2)) $((900 - 72 - 73)))" 000000
leaves "$(now)" >/dev/null

# A scale where the card comes out a fraction of a pixel wide, and a row
# through it: the window has the whole card, its edges are those of scale 1.
fraction() {
	theme "{\"scale\":$1}"
	show volume 0.5
	sleep 0.4
	shot "scale-$1"
	same "at $1: edges" "$(edges "scale-$1" "$2")" "$(edges volume-dark $middle)"
	leaves "$(now)" >/dev/null
}
fraction 1.3 805
fraction 0.7 848
theme '{}'

# The window comes out.
ipc poke under
sleep 0.6
niri msg action maximize-column
sleep 0.6

tile() {
	niri msg --json windows | jq -r '.[0].layout.tile_size | join("x")'
}
size=$(tile)

# On top of the window: a click and a key go to the window, not to the card,
# and the window keeps its size.
move 700 $middle
show volume 0.4
sleep 0.4
shot over-window
same "the window's size under it" "$(tile)" "$size"
click
wait_log "okaeri: under: click 1"
up || fail "it was gone by the time of the click"
type x
wait_log "okaeri: under: key x"
leaves "$(now)" >/dev/null

# The service comes up, on a value that isn't 0: no change.
ipc poke audio true 0.6 false
stays_off 1300 "it showed as Audio came up"

# Now that's a change.
ipc poke audio true 0.3 false
comes_up "no card for a real volume change"
sleep 0.4
shot real-volume
between "real volume" "$(filled real-volume ffffff)" 57 63
leaves "$(now)" >/dev/null

ipc poke audio true 0.3 true
comes_up "no card for a real mute"
sleep 0.4
shot real-mute
between "real mute" "$(filled real-mute 898989)" 57 63
[ "$(icon real-mute)" = "$(icon mute-dark)" ] || fail "no mute icon for a real mute"
leaves "$(now)" >/dev/null

ipc poke audio true 0.3 false
comes_up "no card for a real unmute"
sleep 0.4
shot real-unmute
between "real unmute" "$(filled real-unmute ffffff)" 57 63
leaves "$(now)" >/dev/null

# The service goes away and comes back, on another value: no change either.
ipc poke audio false 0 false
stays_off 1300 "it showed as Audio went away"
ipc poke audio true 0.8 false
stays_off 1300 "it showed as Audio came back"

# Another device's volume is no change of this one's.
ipc poke sink 0.5
stays_off 1300 "it showed for another device"

ipc poke audio true 0.2 false
comes_up "no card for a change on the new device"
sleep 0.4
shot real-new-device
between "the new device's volume" "$(filled real-new-device ffffff)" 37 43
leaves "$(now)" >/dev/null

ipc poke brightness 0.5
comes_up "no card for a real brightness change"
sleep 0.4
shot real-brightness
between "real brightness" "$(filled real-brightness ffffff)" 97 103
[ "$(icon real-brightness)" = "$(icon brightness-dark)" ] || fail "no sun for a real brightness change"
leaves "$(now)" >/dev/null

# The keyboard layout, with two of them: a card as it changes, with no track.
printf 'input {\n\tkeyboard {\n\t\txkb {\n\t\t\tlayout "us,ru"\n\t\t}\n\t}\n}\n' >>"$work/niri.kdl"
sleep 1.6
stays_off 300 "it showed as the layouts came"
niri msg action switch-layout next
comes_up "no card for the keyboard layout"
sleep 0.4
shot layout
niri msg --json layers | jq -e 'any(.[]; .namespace == "okaeri-osd" and .keyboard_interactivity == "None")' >/dev/null ||
	fail "the layout's card took the keyboard"
# By its whole name, Russian, and not RU: a card of two letters would be about 75
# pixels across its middle.
wide=$(magick "$out/layout.png" -depth 8 -crop "1400x1+0+$middle" +repage txt:- | grep -vci "#$desk" || true)
[ "$wide" -gt 90 ] || fail "the layout's card is $wide pixels wide, as for two letters"
leaves "$(now)" >/dev/null

# The lock keys, by their lights: a card as one changes, saying which and how.
light() {
	echo "$2" >"$work/leds/input9::$1/brightness"
}
# Whether two shots show something else where the card is.
cards_differ() {
	[ "$(magick "$out/$1.png" "$out/$2.png" -compose difference -composite -crop 400x120+500+760 +repage -format '%[fx:maxima]' info:)" != 0 ]
}
stays_off 500 "a card for a light that didn't change"
light capslock 1
comes_up "no card for CapsLock on"
sleep 0.4
shot caps-on
leaves "$(now)" >/dev/null
light capslock 0
comes_up "no card for CapsLock off"
sleep 0.4
shot caps-off
leaves "$(now)" >/dev/null
cards_differ caps-on caps-off || fail "CapsLock on and off look the same"
light numlock 1
comes_up "no card for NumLock"
sleep 0.4
shot num-on
leaves "$(now)" >/dev/null
cards_differ caps-on num-on || fail "CapsLock and NumLock look the same"

# Its settings, as the settings window leaves them.
settings() {
	printf '%s\n' "$1" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	sleep 0.5
}

# The microphone's volume has one too.
ipc poke micVolume 0.3
comes_up "no card for the microphone's volume"
sleep 0.4
shot mic-volume
between "the microphone's volume" "$(filled mic-volume ffffff)" 57 63
leaves "$(now)" >/dev/null

# What the settings turn off has no card, but a call still does.
settings '{ "osd": { "hidden": ["volume", "mic"] } }'
ipc poke audio true 0.5 false
stays_off 1300 "a card for the volume, with that off"
ipc poke micVolume 0.6
stays_off 1300 "a card for the microphone, with that off"
show volume 0.4
comes_up "no card on a call, with the volume off"
leaves "$(now)" >/dev/null
settings '{}'

# A volume that goes past 100% fills the slider at its limit.
ipc poke limit 1.5
show volume 0.75
sleep 0.4
shot past-full
between "half of the way to 150%" "$(filled past-full ffffff)" 97 103
leaves "$(now)" >/dev/null
ipc poke limit 1

# As long as it's set to stay.
settings '{ "osd": { "duration": 3 } }'
show volume 0.4
since=$(now)
between "left after, set to 3 s" "$(leaves "$since")" 2950 3800

# The level in numbers: a wider card.
settings '{ "osd": { "percent": true } }'
show volume 0.4
sleep 0.4
shot numbers
[ "$(edges numbers $middle)" != "$(edges volume-dark $middle)" ] || fail "no numbers beside the slider"
leaves "$(now)" >/dev/null

# At the top, under the bar, and in the middle: nothing where it was.
shot bare
# Whether shot $1 differs from the bare one in the rows from $2, $3 of them.
shows_at() {
	[ "$(magick "$out/$1.png" "$out/bare.png" -compose difference -composite -crop "400x$3+500+$2" +repage -format "%[fx:maxima]" info:)" != 0 ]
}
settings '{ "osd": { "position": "top" } }'
show volume 0.4
sleep 0.4
shot at-top
shows_at at-top 45 120 || fail "no card at the top"
shows_at at-top 760 120 && fail "a card at the bottom, set to the top"
leaves "$(now)" >/dev/null
settings '{ "osd": { "position": "middle" } }'
show volume 0.4
sleep 0.4
shot in-middle
shows_at in-middle 400 100 || fail "no card in the middle"
shows_at in-middle 760 120 && fail "a card at the bottom, set to the middle"
leaves "$(now)" >/dev/null
settings '{}'

# With blur on, as the panels have it: what's under the card shows through.
theme '{"blur":true}'
show volume 0.4
sleep 0.4
shot glass
[ "$(pixel glass $((left + 6)) $((top + 6)))" != 000000 ] || fail "the card isn't see-through with blur on"
leaves "$(now)" >/dev/null
theme '{}'

# What's on or off says so in words, as keeping awake: on and off look apart,
# and with that kind turned off there's no card for it.
ipc awake toggle
comes_up "no card for keeping awake"
sleep 0.4
shot awake-on
ipc awake toggle
sleep 0.4
shot awake-off
# Its card is as wide as its words, about the middle of the screen.
words() {
	magick "$out/$1.png" -crop "300x50+550+$top" +repage -format '%#' info:
}
[ "$(words awake-on)" != "$(words awake-off)" ] || fail "keeping awake looks the same on and off"
[ "$(words awake-on)" != "$(words nothing)" ] || fail "keeping awake has nothing on its card"
leaves "$(now)" >/dev/null
settings '{ "osd": { "hidden": ["awake"] } }'
ipc awake toggle
stays_off 1300 "a card for keeping awake, with that off"
ipc awake toggle
stays_off 500 "a card for keeping awake, with that off"
settings '{}'
