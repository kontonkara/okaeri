# The bar on its own, with an app in its tray and a window beside it. The app is
# a real StatusNotifierItem on the stand's bus, made by Qt in the stand's copy of
# the shell, so its icon and its menu come through D-Bus as an app's do.

fail() {
	echo "bar: $1" >&2
	exit 1
}
step() {
	echo "bar: $1" >&2
}
same() {
	[ "$2" = "$3" ] || fail "$1: got \"$2\", not \"$3\""
}
theme() {
	printf '%s' "$1" >"$XDG_CONFIG_HOME/okaeri/theme.json"
	sleep 0.5
}
# Puts standard input in file $1 at once: a reload mustn't find it half written.
swap() {
	cat >"$work/rewritten"
	mv "$work/rewritten" "$1"
}
# Writes standard input to file $1 in place, for the shell to see it.
rewrite() {
	cat >"$work/rewritten"
	cat "$work/rewritten" >"$1"
}

# How many things shot $1 has on a bar $3 tall, $2 dark columns or more apart.
# Inside the bar, off its edge and its round ends.
things() {
	inset=$(($3 * 12 / 34))
	width=$((1400 - 2 * inset))
	magick "$out/$1.png" -crop "${width}x$((inset * 3 / 2))+$inset+$inset" +repage -colorspace Gray -scale "${width}x1!" txt:- |
		awk -v apart="$2" '
			NR == 1 { next }
			/gray\(0\)|#000000/ { gap++; next }
			{
				if (gap >= apart || !count)
					count++
				gap = 0
			}
			END { print count + 0 }
		'
}

# The widths of the workspaces' pills in shot $1, from the left.
pills() {
	magick "$out/$1.png" -crop 200x1+6+17 +repage -colorspace Gray txt:- |
		awk '
			NR == 1 { next }
			/gray\(0\)|#000000/ { if (run) printf "%d ", run; run = 0; next }
			{ run++ }
		' | sed 's/ $//'
}

shot before
before=$(lane before | wc -l)

magick -size 22x22 xc:white "$work/tray.png"
cat >"$work/shell/Probe.qml" <<QML
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform as Labs
import qs
import qs.services

Scope {
	Labs.SystemTrayIcon {
		id: app

		visible: true
		icon.source: "file://$work/tray.png"
		onActivated: reason => console.info("okaeri-probe: activated", reason)
		menu: Labs.Menu {
			Labs.MenuItem {
				text: "Open"
				onTriggered: console.info("okaeri-probe: open")
			}
			Labs.MenuItem {
				text: "Checked"
				checkable: true
				checked: true
				onTriggered: console.info("okaeri-probe: checked")
			}
			Labs.MenuSeparator {}
			Labs.MenuItem {
				text: "Disabled"
				enabled: false
			}
			Labs.Menu {
				title: "More"
				Labs.MenuItem {
					text: "Deep"
					onTriggered: console.info("okaeri-probe: deep")
				}
				Labs.MenuItem {
					id: extra

					text: "Extra"
					visible: false
				}
				Labs.Menu {
					title: "Further"
					Labs.MenuItem {
						text: "Near"
					}
					Labs.MenuItem {
						text: "Deepest"
						onTriggered: console.info("okaeri-probe: deepest")
					}
				}
			}
			Labs.MenuItem {
				text: "Quit"
			}
		}
	}

	IpcHandler {
		target: "probe"

		function change(): void {
			extra.visible = !extra.visible;
		}

		function leave(): void {
			app.visible = false;
		}

		function come(): void {
			app.visible = true;
		}

		// As if from niri: a nested one has no PipeWire casts.
		function niri(event: string): void {
			Niri.handle(JSON.parse(event));
		}

		function twice(): void {
			Niri.act({ FocusWorkspaceDown: {} });
			Niri.act({ FocusWorkspaceDown: {} });
		}

		// A place for the weather, by its name.
		function locate(name: string): void {
			Weather.locate(name);
		}

		// As if apps listened and watched.
		function privacy(microphone: string, camera: string): void {
			Privacy.microphone = microphone ? microphone.split(",") : [];
			Privacy.camera = camera ? camera.split(",") : [];
		}

		// What else has a battery, as "Mouse=80;Buds=35", and what the line then says
		// of it.
		function others(devices: string): string {
			Power.others = devices.split(";").map(device => ({ name: device.split("=")[0], percent: Number(device.split("=")[1]) }));
			return Power.othersLine;
		}

		// When the sun rises and sets on a day, as minutes of it at Greenwich.
		function sun(day: string): string {
			const date = new Date(day + "T12:00:00");
			const times = Theme.sunOn(date);
			return times ? Math.round(times.rise + date.getTimezoneOffset()) + " " + Math.round(times.set + date.getTimezoneOffset()) : "none";
		}

		function record(): void {
			Recorder.toggle();
		}

		// As if from the machine's battery.
		function battery(charge: int, draining: bool, left: int): void {
			Power.charge = charge;
			Power.draining = draining;
			Power.timeLeft = left;
		}
	}
}
QML
# Says what becomes of a pill and what the clock shows, in this copy.
sed 's/^\t\t\trequired property var modelData$/&\n\n\t\t\tComponent.onCompleted: console.info("okaeri: pill made")\n\t\t\tonWidthChanged: console.info("okaeri: pill", width)/' \
	"$work/shell/bar/Workspaces.qml" | swap "$work/shell/bar/Workspaces.qml"
sed 's/^\tid: time$/&\n\n\treadonly property string shows: visible ? text : "nothing"\n\n\tonShowsChanged: console.info("okaeri: clock:", shows)\n\tComponent.onCompleted: console.info("okaeri: clock:", shows)/' \
	"$work/shell/bar/Clock.qml" | swap "$work/shell/bar/Clock.qml"
# What listens and watches is what the probe says: part.sh took the machine's own out.
grep -q '^	property var microphone: \[\]$' "$work/shell/services/Privacy.qml" || fail "the stand's Privacy is the machine's"
# And the control center, for a panel to open over a menu.
sed -e '0,/^import qs\.bar$/s//&\nimport qs.control/' -e 's/^\tScope {}$/\tProbe {}\n\n\tControlCenter {}/' \
	"$work/shell/shell.qml" | swap "$work/shell/shell.qml"
wait_log 'Reloading configuration'
# That reload began with the first of these, and may have read the rest as they
# were before: a file put in another's place isn't seen again. Once it's done,
# one more, with all of them there.
loaded() {
	for _ in $(seq 50); do
		[ "$(log | grep -c "Configuration Loaded")" -ge "$1" ] && return 0
		sleep 0.1
	done
	fail "the shell loaded $(log | grep -c "Configuration Loaded") times, not $1"
}
loaded 2
rewrite "$work/shell/shell.qml" <"$work/shell/shell.qml"
loaded 3

# Until the app is on the bar, and then where.
wait_tray() {
	for _ in $(seq 50); do
		shot tray
		[ "$(lane tray | wc -l)" -gt "$before" ] && break
		sleep 0.1
	done
	[ "$(lane tray | wc -l)" -gt "$before" ] || fail "no icon in the tray"
	tray=$(lane tray | head -n 1)
}
wait_tray

step "The icon"
acts() {
	log | sed -n 's/.*okaeri: dry: tray //p'
}
seen=0
# The next thing done to the app was $1, and the only one.
did() {
	seen=$((seen + 1))
	for _ in $(seq 20); do
		[ "$(acts | wc -l)" -ge "$seen" ] && break
		sleep 0.1
	done
	same "what was done" "$(acts | sed -n "${seen}p")" "$1"
	[ "$(acts | wc -l)" -eq "$seen" ] || fail "more than $1: $(acts | tail -n 1)"
}
move "$tray" 16
click
did activate
click middle
did "secondary activate"
wheel 1
did "scroll 1"
wheel -2
did "scroll -2"
! log | grep -q 'okaeri-probe:' || fail "a dry run reached the app"

step "A window with the keys"
file=$XDG_RUNTIME_DIR/typed
: >"$file"
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 sh -c "cat >>$file" &
for _ in $(seq 50); do
	[ "$(niri msg --json windows | jq length)" = 1 ] && break
	sleep 0.1
done
[ "$(niri msg --json windows | jq length)" = 1 ] || fail "no window"
sleep 1
lines=0
# Types $1 and Enter, and the window got that as the next line, and no more.
reaches() {
	type "$1"
	key Return
	lines=$((lines + 1))
	for _ in $(seq 20); do
		[ "$(wc -l <"$file")" -ge "$lines" ] && break
		sleep 0.1
	done
	same "what the window got" "$(sed -n "${lines}p" "$file")" "$1"
}
reaches first

step "The menu has the keys"
up() {
	niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-panel")] | length'
}
# Until $1 of the panels are up, or fails after 3 s.
wait_up() {
	for _ in $(seq 30); do
		[ "$(up)" = "$1" ] && return 0
		sleep 0.1
	done
	fail "$(up) panels up, not $1"
}
menu() {
	move "$tray" 16
	click right
	wait_up 1
	sleep 0.3
}
# Row by row: to More in the app's menu, and into it.
into_more() {
	key Down
	key Down
	key Return
	sleep 0.3
}
menu
shot menu
# Where every panel's card starts, and around the middle of the icon.
pixel() {
	magick "$out/$1.png" -format "%[pixel:p{$2,$3}]" info:
}
same "above the menu" "$(pixel menu "$tray" 41)" "$(pixel before "$tray" 41)"
[ "$(pixel menu "$tray" 42)" != "$(pixel before "$tray" 42)" ] || fail "the menu doesn't start where a panel does"
type abc
key Down
key Return
did "menu 1"
reaches after-a-row

step "Escape"
menu
key Escape
reaches after-escape
menu
into_more
shot more
key Escape
sleep 0.2
key Down
key Return
did "menu 1"
reaches after-a-way-back

step "A submenu has what's in it"
menu
into_more
key Down
key Return
did "menu 1"
reaches after-a-submenu
menu
into_more
key Down
key Down
key Return
sleep 0.3
shot further
key Down
key Down
key Return
did "menu 2"
reaches after-two-submenus

step "The app changes a menu above the one shown"
menu
into_more
key Down
key Down
key Return
sleep 0.3
ipc probe change
sleep 0.5
key Down
key Down
key Return
did "menu 2"
reaches after-a-change
# And the row it added is there, where Further was.
menu
into_more
key Down
key Down
key Return
did "menu 2"
reaches after-a-new-row
ipc probe change

step "A click elsewhere"
menu
move 300 600
click
reaches after-a-click

step "The pointer"
# As a hand gets there: the rows hear of it from the next events on.
glide() {
	move "$1" "$2"
	wlrctl pointer move 1 0
	wlrctl pointer move 1 0
	sleep 0.1
}
menu
glide "$tray" 191
click
sleep 0.3
# Back, and into it again.
glide "$tray" 68
click
sleep 0.3
glide "$tray" 191
click
sleep 0.3
glide "$tray" 106
click
did "menu 1"
reaches after-the-pointer
# A second click as it fades does nothing more.
menu
glide "$tray" 68
wlrctl pointer click left
wlrctl pointer click left
sleep 0.4
did "menu 0"
reaches after-a-double-click

step "The bar doesn't take the keys"
move 400 16
click
reaches after-the-bar

step "A panel takes a menu's place"
menu
ipc control toggle
sleep 0.5
wait_up 1
key Escape
wait_up 0
reaches after-a-panel

step "Hidden"
settings() {
	printf '%s\n' "$1" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	sleep 0.4
}
item=$(dbus-send --session --print-reply --dest=org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.freedesktop.DBus.Properties.Get \
	string:org.kde.StatusNotifierWatcher string:RegisteredStatusNotifierItems | sed -n 's/.*string "\(.*\)"/\1/p' | head -n 1)
id=$(dbus-send --session --print-reply --dest="${item%%/*}" "/${item#*/}" org.freedesktop.DBus.Properties.Get \
	string:org.kde.StatusNotifierItem string:Id | sed -n 's/.*string "\(.*\)"/\1/p')
[ -n "$id" ] || fail "the app has no id"
move 300 600
settings "{ \"tray\": { \"hidden\": [\"$id\"] } }"
shot hidden
same "what's on the bar with the app hidden" "$(lane hidden | wc -l)" "$before"
settings "{ \"tray\": { \"hidden\": [\"nobody\"] } }"
wait_tray

step "In a drawer"
panels() {
	niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-panel")] | length'
}
wait_panels() {
	for _ in $(seq 30); do
		[ "$(panels)" = "$1" ] && return 0
		sleep 0.1
	done
	fail "$2: $(panels) panels up, not $1"
}
settings '{ "tray": { "drawer": true } }'
move 300 600
sleep 0.2
shot drawer-bar
opener=$(lane drawer-bar | head -n 1)
# Under the button, on the panel's only icon.
icon_y=62
move "$opener" 16
click
wait_panels 1 "a click on the drawer's button"
sleep 0.3
shot drawer
move "$opener" "$icon_y"
click
did activate
wait_panels 0 "a click on an icon in the drawer"

# Its menu takes the drawer's place.
move "$opener" 16
click
wait_panels 1 "the drawer again"
sleep 0.3
move "$opener" "$icon_y"
click right
sleep 0.5
shot drawer-menu
wait_panels 1 "the menu from the drawer"
key Escape
wait_panels 0 "Escape from the menu"
settings '{}'
wait_tray
tray=$(lane tray | head -n 1)

step "What's on the bar"
move 300 600
sleep 0.2
shot bar-all
all=$(lane bar-all | wc -l)
settings '{ "bar": { "right": ["control"] } }'
shot bar-one
same "what's on the right with one part" "$(lane bar-one | wc -l)" 1
one=$(lane bar-one)
settings '{ "bar": { "right": ["control", "battery"] } }'
shot bar-swapped
[ "$(lane bar-swapped | head -n 1)" -lt "$one" ] || fail "the battery didn't go after the control center"
settings '{ "bar": { "center": [], "right": ["nothing", "clock"] } }'
wait_log 'okaeri: no "nothing" for the bar'
shot bar-clock
[ "$(lane bar-clock | wc -l)" -ge 1 ] || fail "no clock on the right"
settings '{}'
shot bar-back
same "what's on the bar afterwards" "$(lane bar-back | wc -l)" "$all"
wait_tray

step "The keyboard layout"
# On the bar if it's asked for. With one layout it takes no room, with two it
# shows the one that's on.
settings '{ "bar": { "right": ["tray", "keyboard", "notifications", "clipboard", "battery", "control"] } }'
move 300 600
sleep 0.2
shot layouts-one
one=$(lane layouts-one | wc -l)
cp "$work/niri.kdl" "$work/niri.kdl.one"
printf 'input {\n\tkeyboard {\n\t\txkb {\n\t\t\tlayout "us,ru"\n\t\t}\n\t}\n}\n' >>"$work/niri.kdl"
for _ in $(seq 30); do
	shot layouts-two
	[ "$(lane layouts-two | wc -l)" -gt "$one" ] && break
	sleep 0.1
done
[ "$(lane layouts-two | wc -l)" -gt "$one" ] || fail "no keyboard layout on the bar"
keyboard=$(lane layouts-two | sed -n 2p)
move "$keyboard" 16
click
wait_log "okaeri: dry: layout next"
move 300 600
niri msg action switch-layout next
sleep 0.4
shot layouts-ru
[ "$(magick "$out/layouts-two.png" "$out/layouts-ru.png" -compose difference -composite \
	-crop "40x20+$((keyboard - 20))+11" +repage -format '%[fx:maxima * 255 > 8]' info:)" = 1 ] || fail "the layout on the bar didn't change"
cat "$work/niri.kdl.one" >"$work/niri.kdl"
sleep 0.5
settings '{}'

step "Showing the screen"
# A PipeWire cast: stream $1, session $2, streaming or not ($3).
pipewire() {
	ipc probe niri "{\"CastStartedOrChanged\":{\"cast\":{\"stream_id\":$1,\"session_id\":$2,\"kind\":\"PipeWire\",\"target\":{\"Output\":{\"name\":\"HEADLESS-1\"}},\"is_dynamic_target\":false,\"is_active\":$3,\"pid\":null,\"pw_node_id\":7}}}"
	sleep 0.3
}
move 300 600
sleep 0.2
shot casts-none
none=$(lane casts-none | wc -l)
pipewire 1 1 false
shot casts-paused
same "what's on the bar with a paused cast" "$(lane casts-paused | wc -l)" "$none"
pipewire 1 1 true
pipewire 2 2 true
pipewire 3 2 true
shot casts-two
same "what's on the bar with casts" "$(lane casts-two | wc -l)" "$((none + 1))"
# One click for all of them, once a session.
cast=$(lane casts-two | head -n 1)
move "$cast" 16
click
wait_log "okaeri: dry: cast stop 1"
wait_log "okaeri: dry: cast stop 2"
same "stops from a click" "$(log | grep -c "okaeri: dry: cast stop")" 2
ipc probe niri '{"CastStopped":{"stream_id":1}}'
ipc probe niri '{"CastStopped":{"stream_id":2}}'
ipc probe niri '{"CastStopped":{"stream_id":3}}'
move 300 600
sleep 0.3
shot casts-gone
same "what's on the bar after the casts" "$(lane casts-gone | wc -l)" "$none"
# A real one that niri can't stop: the icon alone, and a click does nothing.
wf-recorder --no-dmabuf -f "$work/cast.mkv" >"$work/cast.log" 2>&1 &
recorder=$!
for _ in $(seq 50); do
	[ "$(niri msg --json casts | jq length)" = 1 ] && break
	sleep 0.1
done
[ "$(niri msg --json casts | jq length)" = 1 ] || {
	cat "$work/cast.log" >&2
	fail "niri sees no cast"
}
same "the cast's kind" "$(niri msg --json casts | jq -r '.[0].kind')" WlrScreencopy
sleep 0.3
shot cast-real
same "what's on the bar with a real cast" "$(lane cast-real | wc -l)" "$((none + 1))"
stops=$(log | grep -c "okaeri: dry: cast stop" || true)
move "$(lane cast-real | head -n 1)" 16
click
same "stops from a cast that can't be" "$(log | grep -c "okaeri: dry: cast stop" || true)" "$stops"
move 300 600
kill "$recorder"
wait "$recorder" || true
sleep 0.5
shot cast-real-gone
same "what's on the bar after the real cast" "$(lane cast-real-gone | wc -l)" "$none"

step "Two requests at once"
focused() {
	niri msg --json workspaces | jq '.[] | select(.is_focused) | .idx'
}
niri msg action focus-workspace 1
ipc probe twice
for _ in $(seq 20); do
	[ "$(focused)" = 3 ] && break
	sleep 0.1
done
same "the workspace after two steps down" "$(focused)" 3
niri msg action focus-workspace 1

step "Failed units"
move 300 600
sleep 0.2
shot units-none
none=$(lane units-none | wc -l)
printf '[{"unit":"broken.service","load":"loaded","active":"failed","sub":"failed","description":"Something of the system"}]\n' >"$work/failed-system"
printf '[{"unit":"mine.service","load":"loaded","active":"failed","sub":"failed","description":"Something of the user"}]\n' >"$work/failed-user"
ipc units check
sleep 0.4
shot units-two
same "what's on the bar with failed units" "$(lane units-two | wc -l)" "$((none + 1))"
failed=$(lane units-two | head -n 1)
move "$failed" 16
click
wait_up 1
sleep 0.3
shot units-list
key Escape
wait_up 0
# With the last of them gone it all goes, even with the list up.
click
wait_up 1
printf '[]\n' >"$work/failed-system"
printf '[]\n' >"$work/failed-user"
ipc units check
wait_up 0
move 300 600
sleep 0.3
shot units-gone
same "what's on the bar after the failed units" "$(lane units-gone | wc -l)" "$none"

step "What's playing"
# Whether there's anything right of the workspaces in shot $1.
left_of_clock() {
	magick "$out/$1.png" -crop 400x20+150+10 +repage -format '%[fx:maxima]' info:
}
move 300 600
sleep 0.2
shot media-none
same "beside the workspaces with no player" "$(left_of_clock media-none)" 0
mpv --no-config --no-terminal --ao=null --vo=null --loop-playlist=inf --pause --force-media-title="A song with a title long enough to be cut off well before it ends" \
	--script="$OKAERI_MPV_MPRIS" av://lavfi:sine av://lavfi:sine >/dev/null 2>&1 &
player=$!
for _ in $(seq 50); do
	shot media-up
	[ "$(left_of_clock media-up)" != 0 ] && break
	sleep 0.1
done
[ "$(left_of_clock media-up)" != 0 ] || fail "nothing on the bar for a player"
[ "$(magick "$out/media-up.png" -crop 200x20+350+10 +repage -format '%[fx:maxima]' info:)" = 0 ] || fail "a long title wasn't cut off"
move 220 16
click
wait_up 1
sleep 0.4
shot media-card
key Escape
wait_up 0
click middle
wait_log "okaeri: dry: media toggle"
wheel 1
wait_log "okaeri: dry: media previous"
wheel -1
wait_log "okaeri: dry: media next"
# With the player gone it goes, and the card with it.
click
wait_up 1
kill "$player"
wait "$player" || true
wait_up 0
move 300 600
sleep 0.3
shot media-gone
same "beside the workspaces after the player" "$(left_of_clock media-gone)" 0

step "The card's other buttons, and another player"
# What's right of the workspaces in shot $1, for telling two shots apart.
titled() {
	magick "$out/$1.png" -crop 400x20+150+10 +repage -format '%#' info:
}
# Until the log has more lines like $2 than $3, or fails as $1.
logged() {
	for _ in $(seq 50); do
		[ "$(log | grep -cE "$2" || true)" -gt "$3" ] && return 0
		sleep 0.1
	done
	fail "$1: no \"$2\" in the log"
}
lines() {
	log | grep -cE "$1" || true
}
# The name of an mpv on the bus that isn't $1, until there is one.
new_mpv() {
	for _ in $(seq 50); do
		found=$(dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
			org.freedesktop.DBus.ListNames | sed -n 's/.*"\(org\.mpris\.MediaPlayer2\.mpv[^"]*\)"/\1/p' | grep -v -xF "$1" || true)
		[ -n "$found" ] && break
		sleep 0.1
	done
	[ -n "$found" ] || fail "no new player on the bus"
	echo "$found"
}
# Two hundred seconds of quiet: a track whose length is known from the start.
python3 -I -c 'import sys, wave
w = wave.open(sys.argv[1], "wb")
w.setnchannels(1)
w.setsampwidth(1)
w.setframerate(8000)
w.writeframes(b"\x80" * 8000 * 200)
w.close()' "$work/quiet.wav"
mpv --no-config --no-terminal --ao=null --vo=null --force-media-title="Quiet, with a title long enough to be cut off well before it ends" \
	--script="$OKAERI_MPV_MPRIS" "$work/quiet.wav" >/dev/null 2>&1 &
first=$!
first_name=$(new_mpv nothing)
move 300 600
for _ in $(seq 50); do
	shot quiet-up
	[ "$(left_of_clock quiet-up)" != 0 ] && break
	sleep 0.1
done
[ "$(left_of_clock quiet-up)" != 0 ] || fail "nothing on the bar for the player"
move 220 16
click
wait_up 1
sleep 0.5
shot card-timed
# A click halfway along the slider: halfway into the track.
at=$(lines 'media seek ')
move 221 136
click
logged "the slider" "media seek $first_name (9[0-9]|10[0-9])$" "$at"
at=$(lines 'media shuffle ')
move 73 136
click
logged "shuffle" "media shuffle $first_name true" "$at"
at=$(lines 'media loop ')
move 368 136
click
logged "repeat" "media loop $first_name Playlist" "$at"
key Escape
wait_up 0
# A paused one beside it, picked from the card's list: the bar goes to it, and
# the card's buttons.
mpv --no-config --no-terminal --ao=null --vo=null --pause --force-media-title="Another" \
	--script="$OKAERI_MPV_MPRIS" "$work/quiet.wav" >/dev/null 2>&1 &
second=$!
second_name=$(new_mpv "$first_name")
sleep 0.5
move 300 600
sleep 0.2
shot two-players
move 220 16
click
wait_up 1
sleep 0.5
shot card-two
move 200 207
click
sleep 0.3
key Escape
wait_up 0
move 300 600
sleep 0.2
shot picked
[ "$(titled picked)" != "$(titled two-players)" ] || fail "the bar didn't follow the player picked"
# Its title is short.
move 140 16
middle_clicked=$(lines "media toggle $second_name")
click middle
logged "the middle button, after a pick" "media toggle $second_name" "$middle_clicked"
move 300 600
kill "$second"
wait "$second" 2>/dev/null || true
sleep 0.5
# Only while one plays: with the first paused, none does.
settings '{ "media": { "show": "playing" } }'
shot while-playing
[ "$(left_of_clock while-playing)" != 0 ] || fail "nothing on the bar while one plays"
dbus-send --session --print-reply --dest="$first_name" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Pause >/dev/null
sleep 0.5
shot none-playing
same "beside the workspaces with none playing" "$(left_of_clock none-playing)" 0
dbus-send --session --print-reply --dest="$first_name" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Play >/dev/null
# Both mpv: left out, there's no player at all.
settings '{ "media": { "ignored": ["mpv"] } }'
shot left-out
same "beside the workspaces with the players left out" "$(left_of_clock left-out)" 0
settings '{ "media": { "ignored": ["somebody else"] } }'
shot not-left-out
[ "$(left_of_clock not-left-out)" != 0 ] || fail "a player left out that wasn't named"
# How far right what's beside the workspaces reaches in shot $1.
reach() {
	magick "$out/$1.png" -crop 400x20+100+10 +repage -trim -format '%[fx:page.x + w]' info:
}
settings '{ "media": { "label": "none" } }'
shot only-icon
settings '{ "media": { "width": 120 } }'
shot narrow
settings '{}'
shot as-set
[ "$(reach only-icon)" -lt "$(reach narrow)" ] || fail "only the icon is as wide as a title"
[ "$(reach narrow)" -lt "$(reach as-set)" ] || fail "the title isn't narrower when it's set so"
# Under the pointer what's cut slides by, unless that's off.
move 230 16
sleep 1.5
shot sliding-1
sleep 1
shot sliding-2
[ "$(titled sliding-1)" != "$(titled sliding-2)" ] || fail "the title doesn't slide"
settings '{ "media": { "scroll": false } }'
move 300 600
sleep 0.3
move 230 16
sleep 1.5
shot still-1
sleep 1
shot still-2
same "the title with sliding off" "$(titled still-1)" "$(titled still-2)"
settings '{}'
move 300 600
kill "$first"
wait "$first" 2>/dev/null || true
sleep 0.5

step "The window in focus"
settings '{ "bar": { "left": ["workspaces", "title"] } }'
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 -T "The first window" sleep 30 &
first=$!
sleep 1
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 -T "Another" sleep 30 &
second=$!
sleep 1
shot title-second
[ "$(left_of_clock title-second)" != 0 ] || fail "no title on the bar"
niri msg action focus-column-left
sleep 0.4
shot title-first
[ "$(titled title-first)" != "$(titled title-second)" ] || fail "the title didn't follow the focus"
kill "$first" "$second"
wait "$first" "$second" || true
sleep 0.5
shot title-gone
same "beside the workspaces with no window" "$(left_of_clock title-gone)" 0
settings '{}'

step "The wheel on the bar"
levels() {
	log | grep -cE "okaeri: dry: (volume|brightness) " || true
}
# The wheel at $1 $2 makes a line with $3, the next one.
turns() {
	before_lines=$(log | grep -c "okaeri: dry: $3 " || true)
	move "$1" 16
	wheel 1
	sleep 0.2
	[ "$(log | grep -c "okaeri: dry: $3 " || true)" -gt "$before_lines" ] || fail "no $3 from the wheel at $1"
}
turns 300 16 brightness
turns 1000 16 volume
# On a button with no use for it, it goes through.
move 300 600
sleep 0.2
shot wheel-bar
turns "$(lane wheel-bar | tail -n 1)" 16 volume
# The app in the tray has one.
at_levels=$(levels)
tray=$(lane wheel-bar | head -n 1)
move "$tray" 16
wheel 1
did "scroll 1"
same "levels from the wheel on the tray" "$(levels)" "$at_levels"

step "The app goes away"
menu
ipc probe leave
wait_up 0
reaches after-the-app
move 300 600
ipc probe come
wait_tray

step "What's done reaches the app"
# On this bus only the probe hears it, so here it can go through.
sed 's/if (dry)/if (dry \&\& !what.startsWith("tray"))/' "$work/shell/services/Env.qml" | rewrite "$work/shell/services/Env.qml"
sleep 1
wait_tray
move "$tray" 16
click
wait_log 'okaeri-probe: activated 3'
menu
key Return
wait_log 'okaeri-probe: open'
reaches after-open
menu
into_more
key Down
key Return
wait_log 'okaeri-probe: deep'
reaches after-deep
menu
into_more
key Down
key Down
key Return
sleep 0.3
key Down
key Down
key Return
wait_log 'okaeri-probe: deepest'
reaches after-deepest

step "The workspaces"
# What the pills said from line $1 of the log on, as "made" and "pill" lines.
said() {
	log | tail -n "+$1" | sed -n 's/.*okaeri: pill //p'
}
focus() {
	from=$(($(log | wc -l) + 1))
	niri msg action focus-workspace "$1"
	sleep 0.5
}
focused() {
	niri msg --json workspaces | jq '.[] | select(.is_focused) | .idx'
}
same "the pills at first" "$(shot pills-1; pills pills-1)" "28 12 12 12"
focus 3
same "the pills on the third" "$(shot pills-3; pills pills-3)" "12 12 28 12"
[ "$(said "$from" | grep -c made)" = 0 ] || fail "a change of workspace made the pills anew"
[ "$(said "$from" | grep -cvE '^(12|28)$')" -gt 2 ] || fail "the pill didn't grow: $(said "$from" | tr '\n' ' ')"
move 25 16
click
sleep 0.5
same "a click on the first pill" "$(focused)" 1
same "the pills back on the first" "$(shot pills-back; pills pills-back)" "28 12 12 12"
niri msg action focus-workspace 2
niri msg action move-workspace-up
sleep 0.5
same "the pills with the second moved up" "$(shot pills-moved; pills pills-moved)" "28 12 12 12"
same "the moved workspace" "$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .name')" two
# The wheel goes from one to the next, and stops at the ends.
niri msg action focus-workspace 1
sleep 0.4
move 25 16
wheel 1
sleep 0.4
same "the wheel up on the first" "$(focused)" 1
wheel -1
sleep 0.4
same "the wheel down" "$(focused)" 2
wheel 1
sleep 0.4
same "the wheel back up" "$(focused)" 1

# A window wanting attention marks its workspace, until it doesn't.
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 sleep 20 &
wanting=$!
sleep 1.5
window=$(niri msg --json focused-window | jq .id)
niri msg action focus-workspace 2
move 300 600
sleep 0.5
shot pills-calm
niri msg action set-window-urgent --id "$window"
sleep 0.4
shot pills-urgent
color() {
	magick "$out/$1.png" -format '%[hex:u.p{24,21}]' info: | cut -c1-6 | tr 'A-F' 'a-f'
}
same "an urgent workspace" "$(color pills-urgent)" ee6666
[ "$(color pills-calm)" != ee6666 ] || fail "a calm workspace looks urgent"
niri msg action unset-window-urgent --id "$window"
sleep 0.4
shot pills-over
same "after the attention" "$(color pills-over)" "$(color pills-calm)"
kill "$wanting"
wait "$wanting" 2>/dev/null || true
niri msg action focus-workspace 1
sleep 0.4

theme '{"animations":false}'
focus 3
same "the pills at once" "$(said "$from" | sort -n | tr '\n' ' ')" "12 28 "
theme '{}'
focus 1

step "The clock on a narrow screen"
# Everything on the bar stays apart as the screen gets narrower. Past where the
# clock fits with its date it goes on without, and then it goes.
clock() {
	log | sed -n 's/.*okaeri: clock: //p' | tail -n 1
}
screen=$(niri msg --json outputs | jq -r 'keys[0]')
move 300 600
shot wide
wide=$(things wide 10 34)
shown=
for scale in 2 2.4 2.8 3 3.2 3.4 3.6 3.8 4; do
	niri msg output "$screen" scale "$scale"
	sleep 1
	shot "narrow-$scale"
	case $(clock) in
	nothing)
		shown="$shown nothing"
		left=$((wide - 1))
		;;
	*\ *)
		shown="$shown date"
		left=$wide
		;;
	*)
		shown="$shown time"
		left=$wide
		;;
	esac
	same "what's on the bar at a scale of $scale" \
		"$(things "narrow-$scale" "$(awk "BEGIN { print int(10 * $scale) }")" "$(awk "BEGIN { print int(34 * $scale) }")")" "$left"
	[ "$left" = "$wide" ] || break
done
niri msg output "$screen" scale 1
sleep 1
case $shown in
*date*time*nothing) ;;
*) fail "the clock went through$shown" ;;
esac

step "Tips"
# Whether shot $1 has anything under the bar around $2, where shot $3 has not.
under() {
	[ "$(magick "$out/$1.png" "$out/$3.png" -compose difference -composite \
		-crop "200x40+$(($2 - 100))+44" +repage -format '%[fx:maxima > 0.05]' info:)" = 1 ]
}
move 300 600
sleep 0.8
shot tips-none
move 700 16
sleep 1.2
shot tip-clock
under tip-clock 700 tips-none || fail "no tip under the clock"
move 300 600
sleep 0.5
shot tips-gone
under tips-gone 700 tips-none && fail "the tip stayed"
move "$tray" 16
sleep 1.2
shot tip-tray
under tip-tray "$tray" tips-none || fail "no tip under the tray's icon"
move 300 600
settings '{ "bar": { "tips": false } }'
move 700 16
sleep 1.2
shot tip-off
under tip-off 700 tips-none && fail "a tip with them off"
move 300 600
settings '{}'

step "The screens with a bar"
bars() {
	niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-bar")] | length'
}
same "bars at first" "$(bars)" 1
settings "{ \"bar\": { \"hideOn\": [\"$screen\"] } }"
sleep 0.4
same "bars with none here" "$(bars)" 0
shot no-bar
same "where the bar was" "$(pixel no-bar 700 20)" "$(pixel no-bar 700 300)"
# What opens starts at the top, with no bar to go under.
ipc control toggle
wait_up 1
sleep 0.5
shot no-bar-panel
[ "$(pixel no-bar-panel 1300 12)" != "$(pixel no-bar 1300 12)" ] || fail "the panel doesn't start at the top"
key Escape
wait_up 0
settings '{ "bar": { "hideOn": ["nowhere"] } }'
sleep 0.4
same "bars with another screen left out" "$(bars)" 1
settings '{}'
wait_tray

step "What the wheel does"
for does in volume brightness; do
	settings "{ \"bar\": { \"wheel\": \"$does\" } }"
	turns 300 16 "$does"
	turns 1000 16 "$does"
done
settings '{ "bar": { "wheel": "none" } }'
at_levels=$(levels)
move 300 16
wheel 1
move 1000 16
wheel -1
sleep 0.2
same "levels from the wheel with it doing nothing" "$(levels)" "$at_levels"
settings '{ "bar": { "wheel": "workspaces" } }'
niri msg action focus-workspace 1
sleep 0.4
move 300 16
wheel -1
sleep 0.4
same "the wheel on the bar, down" "$(focused)" 2
same "levels from the wheel on the workspaces" "$(levels)" "$at_levels"
niri msg action focus-workspace 1
settings '{}'

step "What the clock says"
# Until the clock says what fits $2, or fails as $1.
says() {
	for _ in $(seq 30); do
		clock | grep -qE "$2" && return 0
		sleep 0.1
	done
	fail "$1: the clock says \"$(clock)\""
}
says "at first" '^[^ ]+ [0-9]{1,2} [^ ]+  [0-9]{2}:[0-9]{2}$'
settings '{ "clock": { "date": "none" } }'
says "with no date" '^[0-9]{2}:[0-9]{2}$'
settings '{ "clock": { "date": "after", "dateFormat": "yyyy" } }'
says "with the year after it" '^[0-9]{2}:[0-9]{2}  [0-9]{4}$'
settings '{ "clock": { "date": "none", "hours12": true, "seconds": true } }'
says "in twelve hours, with seconds" '^[0-9]{1,2}:[0-9]{2}:[0-9]{2} [^ ]+$'
settings '{}'
says "back" '^[^ ]+ [0-9]{1,2} [^ ]+  [0-9]{2}:[0-9]{2}$'

step "The month"
# Whether the days under the clock look other in shots $1 and $2.
months_apart() {
	[ "$(magick "$out/$1.png" "$out/$2.png" -compose difference -composite \
		-crop 320x270+540+95 +repage -format '%[fx:maxima > 0.05]' info:)" = 1 ]
}
move 700 16
click
wait_up 1
sleep 0.5
shot month
move 567 71
click
sleep 0.3
shot month-before
months_apart month month-before || fail "the arrow didn't go to another month"
# Its name goes back to this one.
move 700 71
click
sleep 0.3
shot month-back
months_apart month month-back && fail "the month's name didn't go back to this one"
move 700 220
wheel 1
sleep 0.3
move 700 500
shot month-wheel
months_apart month-wheel month-before && fail "the wheel up didn't go back a month"
move 700 71
click
settings '{ "clock": { "weekStart": "sunday" } }'
shot month-sunday
settings '{ "clock": { "weekStart": "monday" } }'
shot month-monday
months_apart month-sunday month-monday || fail "the weeks start on the same day either way"
settings '{ "clock": { "weekNumbers": true } }'
shot month-numbered
months_apart month-monday month-numbered || fail "no numbers beside the weeks"
settings '{}'
key Escape
wait_up 0

step "The workspaces as they're set"
niri msg action focus-workspace 1
move 300 600
sleep 0.4
shot pills-plain
settings '{ "workspaces": { "labels": "number" } }'
shot pills-numbers
settings '{ "workspaces": { "labels": "name" } }'
shot pills-names
looks_apart() {
	[ "$(magick "$out/$1.png" "$out/$2.png" -compose difference -composite \
		-crop 200x30+6+6 +repage -format '%[fx:maxima > 0.05]' info:)" = 1 ] || fail "$3"
}
looks_apart pills-plain pills-numbers "the pills say no numbers"
looks_apart pills-numbers pills-names "the pills say no names"
settings '{}'
# A window on the first, and the second in focus: the first stands out from the
# empty ones, unless that's off.
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 sleep 30 &
holding=$!
sleep 1.5
niri msg action focus-workspace 2
move 300 600
sleep 0.5
shot pills-busy
settings '{ "workspaces": { "occupied": false } }'
shot pills-alike
[ "$(color pills-busy)" != "$(color pills-alike)" ] || fail "one with a window looks like an empty one"
# Without the empty ones: the first with its window, and the second, in focus.
settings '{ "workspaces": { "empty": false } }'
same "the pills without the empty ones" "$(shot pills-busy-only; pills pills-busy-only)" "12 28"
# With the apps on each, the first has an icon for each of its two: the one the
# icon theme has in its colors, and a sign for the one nobody knows. A click on
# one goes to that app's window, not to the one the workspace last showed.
niri msg action focus-workspace 1
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --class okaeri-unknown --config NONE -o confirm_os_window_close=0 sleep 30 &
unknown=$!
sleep 1.5
niri msg action focus-workspace 2
move 300 600
sleep 0.5
settings '{ "workspaces": { "apps": true } }'
shot pills-apps
# Whether the 16 pixels from $2 across in shot $1 are warm in color, as a whole:
# the edges of letters have colors of their own, which even out.
colorful() {
	magick "$out/$1.png" -crop "16x16+$2+13" +repage -format '%[fx:mean.r - mean.b > 0.01]' info:
}
same "the icon of an app" "$(colorful pills-apps 23)" 1
same "the sign for an unknown one" "$(colorful pills-apps 43)" 0
looks_apart pills-busy-only pills-apps "the first shows no apps"
app_in_focus() {
	niri msg --json focused-window | jq -r .app_id
}
move 31 21
click
sleep 0.5
same "a click on the first icon" "$(app_in_focus)" kitty
niri msg action focus-workspace 2
sleep 0.4
move 51 21
click
sleep 0.5
same "a click on the second icon" "$(app_in_focus)" okaeri-unknown
kill "$unknown"
wait "$unknown" 2>/dev/null || true
niri msg action focus-workspace 2
move 300 600
sleep 0.4
# The other way: up goes to the next one.
settings '{ "workspaces": { "reverse": true } }'
niri msg action focus-workspace 1
sleep 0.4
move 20 16
wheel 1
sleep 0.4
same "the wheel up, the other way" "$(focused)" 2
settings '{}'
kill "$holding"
wait "$holding" 2>/dev/null || true
niri msg action focus-workspace 1
sleep 0.4

step "The battery as it's set"
move 300 600
ipc probe battery 50 false 0
sleep 0.3
shot battery-on
with=$(lane battery-on | wc -l)
settings '{ "battery": { "show": "battery" } }'
shot battery-charger
same "what's on the bar on the charger" "$(lane battery-charger | wc -l)" "$((with - 1))"
ipc probe battery 50 true 7500
sleep 0.3
shot battery-draining
same "what's on the bar on battery" "$(lane battery-draining | wc -l)" "$with"
settings '{ "battery": { "show": "low" } }'
shot battery-not-low
same "what's on the bar while it isn't low" "$(lane battery-not-low | wc -l)" "$((with - 1))"
ipc probe battery 15 true 7500
sleep 0.3
shot battery-low
same "what's on the bar while it's low" "$(lane battery-low | wc -l)" "$with"
settings '{ "battery": { "label": "time" } }'
ipc probe battery 50 true 7500
sleep 0.3
shot battery-time
settings '{ "battery": { "label": "none" } }'
shot battery-bare
right_end() {
	magick "$out/$1.png" -crop 300x20+1000+12 +repage -format '%#' info:
}
[ "$(right_end battery-on)" != "$(right_end battery-time)" ] || fail "the time left looks like the percent"
[ "$(right_end battery-time)" != "$(right_end battery-bare)" ] || fail "nothing beside it looks like the time"
settings '{}'
ipc probe battery 100 false 0

step "An icon kept out of the drawer"
settings "{ \"tray\": { \"drawer\": true, \"pinned\": [\"$id\"] } }"
move 300 600
sleep 0.3
shot pinned
same "what's on the bar with the one icon kept out" "$(lane pinned | wc -l)" "$(lane wheel-bar | wc -l)"
# It's the app's own by now: what's done reaches it.
activated=$(log | grep -c 'okaeri-probe: activated' || true)
move "$(lane pinned | head -n 1)" 16
click
for _ in $(seq 20); do
	[ "$(log | grep -c 'okaeri-probe: activated')" -gt "$activated" ] && break
	sleep 0.1
done
[ "$(log | grep -c 'okaeri-probe: activated')" -gt "$activated" ] || fail "the icon kept out didn't reach the app"
settings '{}'
wait_tray

step "The network and Bluetooth"
# On what's really here, only read: a machine with Wi-Fi or a wire has the one,
# and with its adapter on the other.
move 300 600
sleep 0.2
shot online-none
none=$(lane online-none | wc -l)
settings '{ "bar": { "right": ["network", "bluetooth", "control"] } }'
sleep 0.6
shot online-bare
settings '{ "bar": { "right": ["network", "bluetooth", "control"] }, "bluetooth": { "show": "on" } }'
sleep 0.6
shot online-on
# The network and the control center, and Bluetooth while its adapter is on; with
# a device only, no more than that.
powered=0
[ "$(busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered 2>/dev/null)" = "b true" ] && powered=1
same "what's on the right with Bluetooth while it's on" "$(lane online-on | wc -l)" "$((2 + powered))"
[ "$(lane online-bare | wc -l)" -le "$(lane online-on | wc -l)" ] || fail "more with a device only than while it's on"
# The network's name beside it, when it has one: the right half reaches further.
settings '{ "bar": { "right": ["network", "control"] } }'
sleep 0.6
shot network-bare
settings '{ "bar": { "right": ["network", "control"] }, "network": { "label": "name" } }'
sleep 0.6
shot network-named
if nmcli -t -f STATE general 2>/dev/null | grep -q '^connected'; then
	[ "$(lane network-named | head -n 1)" -lt "$(lane network-bare | head -n 1)" ] || fail "no name beside the network"
fi
move "$(lane network-bare | head -n 1)" 16
sleep 1.2
shot network-tip
[ "$(magick "$out/network-tip.png" "$out/network-bare.png" -compose difference -composite \
	-crop "300x40+1100+44" +repage -format '%[fx:maxima > 0.05]' info:)" = 1 ] || fail "no tip under the network"
# A click opens the control center at Wi-Fi's page: Escape goes back to the
# tiles, and then closes it.
click
wait_up 1
key Escape
sleep 0.3
wait_up 1
key Escape
wait_up 0
move 300 600
settings '{}'
wait_tray
shot online-after
same "what's on the bar after" "$(lane online-after | wc -l)" "$none"

step "System load"
# On what's really here, only read. Where what's right of the clock starts.
right_start() {
	magick "$out/$1.png" -crop 500x20+900+10 +repage -trim -format '%[fx:page.x + 900]' info:
}
move 300 600
settings '{ "bar": { "right": ["system", "control"] } }'
sleep 2.5
shot load
[ "$(lane load | wc -l)" -gt 1 ] || fail "nothing beside the control center for the load"
settings '{ "bar": { "right": ["system", "control"] }, "system": { "temperature": false } }'
sleep 0.5
shot load-cooler
[ "$(right_start load-cooler)" -gt "$(right_start load)" ] || fail "no narrower without the temperature"
settings '{ "bar": { "right": ["system", "control"] }, "system": { "cpu": false, "memory": false, "temperature": false } }'
sleep 0.5
shot load-nothing
same "what's on the right with nothing to say" "$(lane load-nothing | wc -l)" 1
settings '{}'
wait_tray

step "Microphone and camera"
move 300 600
sleep 0.2
shot privacy-none
ipc probe privacy "Recorder" ""
sleep 0.3
shot privacy-mic
[ "$(right_start privacy-mic)" -lt "$(right_start privacy-none)" ] || fail "nothing for an app on the microphone"
ipc probe privacy "Recorder" "Meeting"
sleep 0.3
shot privacy-both
[ "$(right_start privacy-both)" -lt "$(right_start privacy-mic)" ] || fail "no camera beside the microphone"
move "$(($(right_start privacy-both) + 12))" 16
sleep 1.2
shot privacy-tip
[ "$(magick "$out/privacy-tip.png" "$out/privacy-both.png" -compose difference -composite \
	-crop "400x40+$(($(right_start privacy-both) - 150))+44" +repage -format '%[fx:maxima > 0.05]' info:)" = 1 ] || fail "no tip for who's listening"
move 300 600
ipc probe privacy "" ""
sleep 0.3
shot privacy-gone
same "where they were" "$(right_start privacy-gone)" "$(right_start privacy-none)"

step "The weather"
# A server of its own answers for open-meteo, which isn't asked.
mkdir -p "$work/weather/v1"
cat >"$work/weather/v1/forecast" <<'JSON'
{"current":{"temperature_2m":12.4,"weather_code":3,"is_day":1},"daily":{"time":["2026-11-09","2026-11-10","2026-11-11","2026-11-12"],"weather_code":[3,61,71,0],"temperature_2m_max":[14.1,11.2,3.9,8.0],"temperature_2m_min":[6.2,5.0,-1.3,2.4]}}
JSON
cat >"$work/weather/v1/search" <<'JSON'
{"results":[{"name":"Testville","admin1":"Somewhere","country":"Nowhere","latitude":1.5,"longitude":2.5}]}
JSON
port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work/weather" >"$out/weather-server.log" 2>&1 &
server=$!
sed -e "s|Quickshell.env(\"OKAERI_WEATHER_URL\") \|\| \"https://api.open-meteo.com\"|\"http://127.0.0.1:$port\"|" \
	-e "s|Quickshell.env(\"OKAERI_PLACES_URL\") \|\| \"https://geocoding-api.open-meteo.com\"|\"http://127.0.0.1:$port\"|" \
	"$work/shell/services/Weather.qml" | rewrite "$work/shell/services/Weather.qml"
grep -q "127.0.0.1:$port" "$work/shell/services/Weather.qml" || fail "the stand's weather asks open-meteo"
wait_tray
# A place by its name, as the settings look for one.
ipc probe locate Testville
for _ in $(seq 30); do
	[ "$(jq -r '.weather.place // empty' "$XDG_STATE_HOME/okaeri/settings.json" 2>/dev/null)" = "Testville, Somewhere, Nowhere" ] && break
	sleep 0.1
done
same "the place found" "$(jq -r '.weather.place' "$XDG_STATE_HOME/okaeri/settings.json")" "Testville, Somewhere, Nowhere"
same "where it is" "$(jq -c '[.weather.latitude, .weather.longitude]' "$XDG_STATE_HOME/okaeri/settings.json")" "[1.5,2.5]"
move 300 600
settings '{ "weather": { "on": true } }'
sleep 1
shot weather-off-bar
settings '{ "weather": { "on": true, "bar": true } }'
sleep 0.5
shot weather-on-bar
[ "$(magick "$out/weather-off-bar.png" "$out/weather-on-bar.png" -compose difference -composite \
	-crop 400x20+500+10 +repage -format '%[fx:maxima > 0.05]' info:)" = 1 ] || fail "no weather beside the time"
move 700 16
click
wait_up 1
sleep 0.5
shot weather-month
key Escape
wait_up 0
settings '{ "weather": { "on": false } }'
move 700 16
click
wait_up 1
sleep 0.5
shot month-no-weather
key Escape
wait_up 0
[ "$(magick "$out/weather-month.png" "$out/month-no-weather.png" -compose difference -composite \
	-crop 320x120+540+50 +repage -format '%[fx:maxima > 0.05]' info:)" = 1 ] || fail "no weather over the month"
kill "$server"
wait "$server" 2>/dev/null || true
settings '{}'
move 300 600

step "Space for windows, and no gap"
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 -T "Under the bar" sleep 30 &
under=$!
sleep 1.5
tile() {
	niri msg --json windows | jq -r '[.[] | select(.title == "Under the bar") | .layout.tile_size[1]][0]'
}
kept=$(tile)
settings '{ "bar": { "reserve": false } }'
sleep 0.6
[ "$(tile | cut -d. -f1)" -gt "$(echo "$kept" | cut -d. -f1)" ] || fail "the window doesn't go under the bar: $kept, then $(tile)"
settings '{}'
sleep 0.6
same "the window with the space kept again" "$(tile)" "$kept"
kill "$under"
wait "$under" 2>/dev/null || true
move 300 600
sleep 0.4
shot gap
theme '{ "barMargin": 0 }'
sleep 0.4
shot no-gap
[ "$(pixel no-gap 1 1)" != "$(pixel gap 1 1)" ] || fail "the corner is as it was with no gap"
same "the corner against the screen's edge" "$(pixel no-gap 1 1)" "$(pixel no-gap 20 1)"
theme '{}'

step "A part of one's own"
# What a command prints is a part of the bar: its first line, with the second
# for the pointer on it, read anew every second; or a line of JSON, in red where
# that says so. With nothing printed the part is gone.
# The bar with `mine` and the control center on its right: mine runs $1 every $2.
own() {
	settings "{ \"bar\": { \"right\": [\"mine\", \"control\"], \"scripts\": [{ \"name\": \"mine\", \"command\": \"$1\", \"every\": $2 }]${3:-} } }"
}
# Whether what's on the bar around $2 in shot $1 is red, as a whole.
tinted() {
	[ "$(magick "$out/$1.png" -crop "160x18+$(($2 - 80))+12" +repage -format '%[fx:mean.r - mean.b > 0.01]' info:)" = 1 ]
}
move 300 600
printf 'first\nsaid under it\n' >"$work/says"
own "cat $work/says" 1
sleep 1
shot own
same "what's on the right with it" "$(lane own | wc -l)" 2
mine=$(lane own | head -n 1)
tinted own "$mine" && fail "the part has a color with none asked for"
move "$mine" 16
sleep 1.2
shot own-tip
under own-tip "$mine" own || fail "no tip under the part"
move 300 600
printf '{"text": "a longer one", "tooltip": "said under it", "class": "critical"}\n' >"$work/says"
sleep 1.5
shot own-json
[ "$(lane own-json | head -n 1)" -lt "$mine" ] || fail "the part doesn't say what's printed now"
tinted own-json "$mine" || fail "the part isn't red"
: >"$work/says"
sleep 1.5
shot own-nothing
same "with nothing printed" "$(lane own-nothing | wc -l)" 1
# Run once, it shows each line as it comes, and all it started goes with it.
own "echo one; sleep 1; echo and another; exec sleep 37.3" 0
sleep 0.5
shot own-one
sleep 1.2
shot own-another
[ "$(lane own-another | head -n 1)" -lt "$(lane own-one | head -n 1)" ] || fail "the part doesn't say the next line"
same "what it runs" "$(pgrep -fc 'sleep 37[.]3')" 1
own "echo one; exec sleep 38.3" 0
sleep 0.5
same "what it ran, with another command" "$(pgrep -fc 'sleep 37[.]3')" 0
same "what it runs now" "$(pgrep -fc 'sleep 38[.]3')" 1
settings '{}'
sleep 0.5
same "what it ran, off the bar" "$(pgrep -fc 'sleep 38[.]3')" 0

step "Clicks on a part"
# A command for a button of a part, or for the wheel on it, runs in place of what
# the part does with it, and the other buttons are the part's still.
ran() {
	log | sed -n 's/.*okaeri: dry: run //p' | tr '\n' ','
}
own "echo here" 0 ', "actions": { "mine": { "left": "echo left", "right": "echo right" }, "clock": { "middle": "echo clock", "up": "echo up" } }'
sleep 0.5
shot clicks
mine=$(lane clicks | head -n 1)
# The pointer on a part with a command is still on the part: its tip comes.
move 700 16
sleep 1.2
shot clicks-tip
under clicks-tip 700 clicks || fail "no tip under a part with a command"
move "$mine" 16
click
click right
click middle
move 700 16
click middle
sleep 0.3
# The wheel on it too, the way that has a command: the other does nothing then.
wheel 1
wheel -1
sleep 0.3
same "what the clicks and the wheel ran" "$(ran)" "echo left,echo right,echo clock,echo up,"
click
sleep 0.6
shot clicks-month
under clicks-month 700 clicks || fail "the clock's own click doesn't open the month"
key Escape
sleep 0.4
move 300 600
settings '{}'

step "A bar that hides"
# Out of sight, it leaves the windows the whole screen. The pointer brings it
# back once it rests at the top of the screen, not as it passes, which every
# move here does by the corner; on the bar it stays, and a panel has it too.
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 -T "Under the bar" sleep 30 &
under=$!
sleep 1.5
kept=$(tile)
move 300 600
shot hides-not
settings '{ "bar": { "autoHide": true } }'
sleep 1
shot hides
there() {
	[ "$(pixel "$1" 900 8)" = "$(pixel hides-not 900 8)" ]
}
there hides && fail "the bar stays in sight"
[ "$(tile | cut -d. -f1)" -gt "$(echo "$kept" | cut -d. -f1)" ] || fail "the window doesn't take the bar's place: $kept, then $(tile)"
move 400 600
sleep 0.6
shot hides-passed
there hides-passed && fail "the pointer passing the top brought the bar"
move 700 0
sleep 0.8
shot hides-edge
there hides-edge || fail "the top of the screen doesn't bring the bar"
move 700 20
sleep 1
shot hides-on
there hides-on || fail "the bar went from under the pointer"
move 300 600
sleep 1
shot hides-left
there hides-left && fail "the bar stays with the pointer gone"
ipc control toggle
sleep 0.6
shot hides-panel
there hides-panel || fail "a panel opened without the bar"
ipc control toggle
sleep 1.2
shot hides-closed
there hides-closed && fail "the bar stays with the panel gone"
# Started as one that hides, it's out of sight from the first, and comes as before.
loads=$(log | grep -c "Configuration Loaded")
printf '\n// Once more.\n' >>"$work/shell/bar/Bar.qml"
loaded $((loads + 1))
sleep 0.2
shot hides-start
there hides-start && fail "a bar that hides starts in sight"
move 700 0
sleep 0.8
shot hides-start-edge
there hides-start-edge || fail "the top of the screen doesn't bring a bar that started out of sight"
move 300 600
sleep 1
settings '{}'
sleep 0.6
shot hides-over
there hides-over || fail "the bar that doesn't hide is out of sight"
same "the window with the space kept again" "$(tile)" "$kept"
kill "$under"
wait "$under" 2>/dev/null || true

step "More of the machine on the bar"
# Caps Lock while it's on, the power profile, keeping awake and the night light:
# a click on each of the last three does what its tile does.
settings '{ "bar": { "right": ["locks", "profile", "awake", "night", "control"] } }'
move 300 600
shot machine
same "what's on the right, with no lock on" "$(lane machine | wc -l)" 4
profile_x=$(lane machine | sed -n 1p)
awake_x=$(lane machine | sed -n 2p)
night_x=$(lane machine | sed -n 3p)
echo 1 >"$work/leds/input9::capslock/brightness"
sleep 0.6
shot machine-caps
same "what's on the right, with Caps Lock on" "$(lane machine-caps | wc -l)" 5
echo 0 >"$work/leds/input9::capslock/brightness"
sleep 0.6
dry() {
	log | grep -c "okaeri: dry: $1" || true
}
profiles=$(dry 'power profile')
move "$profile_x" 16
click
sleep 0.3
[ "$(dry 'power profile')" -gt "$profiles" ] || fail "a click on the power profile asks for no other"
move "$awake_x" 16
click
sleep 0.3
same "kept awake, by a click" "$(ipc awake state | jq .on)" true
click
sleep 0.3
same "kept awake no more" "$(ipc awake state | jq .on)" false
nights=$(dry 'night light')
move "$night_x" 16
click
sleep 0.5
[ "$(dry 'night light')" -gt "$nights" ] || fail "a click on the night light doesn't turn it on"
same "the night light, by a click" "$(ipc night state | jq .on)" true
click
sleep 0.3
same "the night light, off again" "$(ipc night state | jq .on)" false
move 300 600
# What else has a battery is in the battery's line.
same "a mouse's battery" "$(ipc probe others 'Mouse=80;Buds=35')" "Mouse 80% · Buds 35%"
# With that asked for, a battery that's low takes the saver profile, and gives
# it back once the charger is in: here on a machine that isn't saving already.
settings '{ "battery": { "saver": true } }'
savers=$(dry 'power profile PowerSaver')
profiles=$(dry 'power profile')
ipc probe battery 10 true 0
sleep 0.4
if [ "$(dry 'power profile PowerSaver')" -gt "$savers" ]; then
	profiles=$(dry 'power profile')
	ipc probe battery 100 false 0
	sleep 0.4
	[ "$(dry 'power profile')" -gt "$profiles" ] || fail "the profile from before the low battery doesn't come back"
else
	[ "$(powerprofilesctl get 2>/dev/null)" = power-saver ] || fail "a low battery doesn't take the saver profile"
	ipc probe battery 100 false 0
fi
settings '{}'

step "Palettes"
# The colors are a palette's: one by name, one of the user's own, and by the
# hour, here with all day being day, and then night.
bar_color() {
	shot "$1"
	pixel "$1" 900 8
}
move 300 600
theme '{ "extends": "nord" }'
same "the bar in a palette" "$(bar_color palette-nord)" "srgb(46,52,64)"
theme '{ "palettes": { "mine": { "colors": { "background": "#112233" } } }, "extends": "mine" }'
same "the bar in a palette of one's own" "$(bar_color palette-own)" "srgb(17,34,51)"
theme '{ "auto": "time", "dayFrom": "00:00", "nightFrom": "24:00", "day": "light", "night": "nord" }'
same "the bar by day" "$(bar_color palette-day)" "srgb(255,255,255)"
theme '{ "auto": "time", "dayFrom": "00:00", "nightFrom": "00:00", "day": "light", "night": "nord" }'
same "the bar by night" "$(bar_color palette-night)" "srgb(46,52,64)"
theme '{}'
# By the sun it's from sunrise to sunset where the settings say one is: at
# Greenwich on the longest day that's 3:43 to 20:21 there, within a few minutes,
# and far north the sun doesn't set that day.
near() {
	[ "$1" -ge $(($2 - 4)) ] && [ "$1" -le $(($2 + 4)) ]
}
settings '{ "nightLight": { "latitude": 51.48, "longitude": 0 } }'
sun=$(ipc probe sun 2026-06-21)
near "${sun% *}" 223 && near "${sun#* }" 1221 || fail "the sun at Greenwich: $sun"
settings '{ "nightLight": { "latitude": 80, "longitude": 0 } }'
same "the sun far north" "$(ipc probe sun 2026-06-21)" none
# The accent from the wallpaper: the pill of the workspace in focus takes a red
# picture's red, and a gray one leaves it as it was.
reddish() {
	magick "$out/$1.png" -format '%[fx:u.p{24,21}.r - u.p{24,21}.b > 0.15]' info:
}
magick -size 64x64 xc:'#cc2222' "$work/red.png"
magick -size 64x64 xc:'#777777' "$work/gray.png"
settings "{ \"wallpaper\": { \"path\": \"$work/red.png\" } }"
shot accent-own
same "the accent without the wallpaper" "$(reddish accent-own)" 0
theme '{ "wallpaperAccent": true }'
sleep 0.5
shot accent-red
same "the accent from a red wallpaper" "$(reddish accent-red)" 1
settings "{ \"wallpaper\": { \"path\": \"$work/gray.png\" } }"
sleep 0.5
shot accent-gray
same "the accent from a gray wallpaper" "$(reddish accent-gray)" 0
theme '{}'
settings '{}'

step "Recording the screen"
# For real: what's asked of the recorder gets to it here, by way of one that
# takes the screen as this stand has it. The part is on the bar while it runs,
# and a click on it stops it, with the file there.
printf '#!/bin/sh\nexec wf-recorder --no-dmabuf "$@"\n' >"$work/recorder"
chmod +x "$work/recorder"
loads=$(log | grep -c "Configuration Loaded")
sed "s|readonly property string tool: \"wf-recorder\"|readonly property string tool: \"$work/recorder\"|" "$work/shell/services/Recorder.qml" | rewrite "$work/shell/services/Recorder.qml"
loaded $((loads + 1))
sleep 1
loads=$(log | grep -c "Configuration Loaded")
sed 's/!what.startsWith("tray")/!what.startsWith("tray") \&\& !what.startsWith("record")/' "$work/shell/services/Env.qml" | rewrite "$work/shell/services/Env.qml"
loaded $((loads + 1))
sleep 1
settings "{ \"bar\": { \"right\": [\"recording\", \"control\"] }, \"recording\": { \"folder\": \"$work/videos\" } }"
move 300 600
shot record-before
same "what's on the right before a recording" "$(lane record-before | wc -l)" 1
ipc probe record
sleep 2.5
shot record-on
same "what's on the right while it's recorded" "$(lane record-on | wc -l)" 2
video=$(ls "$work/videos"/*.mp4 2>/dev/null | head -n 1)
[ -n "$video" ] || fail "no video in the folder: $(ls "$work/videos" 2>&1)"
move "$(lane record-on | head -n 1)" 16
click
for _ in $(seq 50); do
	pgrep -f "wf-recorder --no-dmabuf -f $work/videos" >/dev/null || break
	sleep 0.1
done
pgrep -f "wf-recorder --no-dmabuf -f $work/videos" >/dev/null && fail "the recorder goes on after the click"
[ -s "$video" ] || fail "the video is empty"
move 300 600
sleep 0.5
shot record-off
same "what's on the right after the recording" "$(lane record-off | wc -l)" 1
settings '{}'
