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
	}
}
QML
# Says what becomes of a pill and what the clock shows, in this copy.
sed 's/^\t\t\trequired property var modelData$/&\n\n\t\t\tComponent.onCompleted: console.info("okaeri: pill made")\n\t\t\tonWidthChanged: console.info("okaeri: pill", width)/' \
	"$work/shell/bar/Workspaces.qml" | swap "$work/shell/bar/Workspaces.qml"
sed 's/^\tid: time$/&\n\n\treadonly property string shows: visible ? text : "nothing"\n\n\tonShowsChanged: console.info("okaeri: clock:", shows)\n\tComponent.onCompleted: console.info("okaeri: clock:", shows)/' \
	"$work/shell/bar/Clock.qml" | swap "$work/shell/bar/Clock.qml"
# And the control center, for a panel to open over a menu.
sed -e '0,/^import qs\.bar$/s//&\nimport qs.control/' -e 's/^\tScope {}$/\tProbe {}\n\n\tControlCenter {}/' \
	"$work/shell/shell.qml" | swap "$work/shell/shell.qml"
wait_log 'Reloading configuration'

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

step "The window in focus"
# What's right of the workspaces in shot $1, for telling two shots apart.
titled() {
	magick "$out/$1.png" -crop 400x20+150+10 +repage -format '%#' info:
}
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
