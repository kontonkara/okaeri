# The dock, with real windows beside it: the apps are this machine's own, kitty
# among them, and what it would launch shows as dry lines in the log.

fail() {
	echo "dock: $1" >&2
	exit 1
}
layers() {
	niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-dock")] | length'
}
wait_layers() {
	for _ in $(seq 40); do
		[ "$(layers)" = "$1" ] && return 0
		sleep 0.1
	done
	fail "$2: $(layers) docks up, not $1"
}
settings() {
	printf '%s\n' "$1" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	sleep 0.5
}
pixel() {
	magick "$out/$1.png" -format "%[hex:u.p{$2,$3}]" info: | cut -c1-6
}
launched() {
	log | sed -n 's/.*okaeri: dry: launch //p' | tail -n 1
}
focused() {
	niri msg --json focused-window | jq -r .app_id
}
own=$XDG_STATE_HOME/okaeri/settings.json
# The dock's ends along the bottom of shot $1: the first and the last column that
# isn't the desk, on the row its icons are in.
ends() {
	magick "$out/$1.png" -crop 1400x1+0+860 +repage txt:- | awk -v desk="#$desk" 'NR > 1 && toupper($3) != toupper(desk) { split($1, at, ","); if (first == "") first = at[1]; last = at[1] } END { print first, last }'
}

# None unless it's asked for.
sleep 0.5
move 700 400
shot none
desk=$(pixel none 700 860)
[ "$(layers)" = 0 ] || fail "a dock without being asked for"

# With one app kept, it's there for that: in the middle of the bottom edge, and a
# click launches it.
settings '{ "dock": { "on": true, "pinned": ["kitty"] } }'
wait_layers 1 "with an app kept"
sleep 0.8
shot kept
set -- $(ends kept)
[ -n "${1:-}" ] || fail "nothing at the bottom for the dock"
middle=$((($1 + $2) / 2))
[ "$middle" -gt 690 ] && [ "$middle" -lt 710 ] || fail "the dock isn't in the middle: $1 to $2"
one=$(($2 - $1))
move "$middle" 862
click
sleep 0.4
[ "$(launched)" = kitty ] || fail "a click on a kept app launched \"$(launched)\""
# Under the pointer its icon grows out of the dock, away from the edge, and as
# it starts it hops.
wait_log "okaeri: dock: launching kitty"
shot grown
[ "$(magick "$out/grown.png" "$out/kept.png" -compose difference -composite -crop 40x14+$((middle - 20))+818 +repage -format '%[fx:maxima > 0.1]' info:)" = 1 ] || fail "the icon under the pointer doesn't grow out of the dock"

# A window of it marks it, and another app's window puts that app beside it: the
# dock gets longer.
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 sleep 60 &
first=$!
sleep 1.5
move 700 400
shot running
[ "$(magick "$out/running.png" "$out/kept.png" -compose difference -composite -crop 60x12+$((middle - 30))+884 +repage -format '%[fx:maxima > 0.2]' info:)" = 1 ] || fail "no mark under an app with a window"
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --class okaeri-other --config NONE -o confirm_os_window_close=0 sleep 60 &
second=$!
sleep 1.5
shot two
set -- $(ends two)
[ $(($2 - $1)) -gt $((one + 30)) ] || fail "the dock is no longer with another app: $1 to $2"
left=$1
right=$2
[ "$(focused)" = okaeri-other ] || fail "the new window isn't in focus: $(focused)"
# A click on the first goes to its window.
move $((left + one / 2)) 862
click
sleep 0.5
[ "$(focused)" = kitty ] || fail "a click on an app with a window went to $(focused)"
[ "$(launched)" = kitty ] || fail "a click on an app with a window launched something"
# The wheel on the other goes to its window.
move $((right - one / 2)) 862
wheel 1
sleep 0.5
[ "$(focused)" = okaeri-other ] || fail "the wheel on an app went to $(focused)"
# A right click on it opens its menu, over its icon. It's not an app this
# machine knows, so the menu has keeping it and closing it, and no more.
kept() {
	jq -c .dock.pinned "$own"
}
shot before-menu
click right
sleep 0.6
shot menu
[ "$(pixel menu $((right - one / 2)) 760)" != "$(pixel before-menu $((right - one / 2)) 760)" ] || fail "no menu over the app a right click was on"
key Down
key Return
sleep 0.4
[ "$(kept)" = '["kitty","okaeri-other"]' ] || fail "the menu's first row kept $(kept)"
shot menu-gone
[ "$(pixel menu-gone $((right - one / 2)) 760)" = "$(pixel before-menu $((right - one / 2)) 760)" ] || fail "the menu stays after a row of it was picked"
# The first, dragged past the other, has its place, and isn't gone to for that.
move $((left + one / 2)) 862
hold
wlrctl pointer move 20 0
sleep 0.1
wlrctl pointer move 50 0
sleep 0.3
let_go
sleep 0.3
[ "$(kept)" = '["okaeri-other","kitty"]' ] || fail "an app dragged past another left $(kept)"
[ "$(focused)" = okaeri-other ] || fail "an app that was dragged was gone to: $(focused)"
# The menu lets it go again, and then it's after the one that's kept.
move $((left + one / 2)) 862
click right
sleep 0.6
key Down
key Return
sleep 0.4
[ "$(kept)" = '["kitty"]' ] || fail "the menu of an app that's kept left $(kept)"
# Its last row closes its window.
move $((right - one / 2)) 862
click right
sleep 0.6
key Down
key Down
key Return
for _ in $(seq 30); do
	kill -0 "$second" 2>/dev/null || break
	sleep 0.1
done
if kill -0 "$second" 2>/dev/null; then
	kill "$second"
	fail "the menu's last row didn't close the app's window"
fi
wait "$second" 2>/dev/null || true
# An app the machine knows has a new window in its menu too, first.
launches() {
	log | grep -c 'okaeri: dry: launch kitty$'
}
before=$(launches)
# Alone on the dock again, in its middle.
sleep 0.8
move "$middle" 862
click right
sleep 0.6
key Down
key Return
sleep 0.4
[ "$(launches)" = $((before + 1)) ] || fail "the menu of an app with a window didn't open another: $(launches) launches after $before"
sleep 0.4
move 700 400
shot one-again
set -- $(ends one-again)
[ $(($2 - $1)) -lt $((one + 10)) ] || fail "an app that went is still on the dock: $1 to $2"

# At a side it's upright, in the middle of that edge.
settings '{ "dock": { "on": true, "pinned": ["kitty"], "position": "left" } }'
sleep 0.8
move 700 400
shot at-left
[ "$(pixel at-left 30 450)" != "$desk" ] || fail "no dock at the left"
# Under the window, which has the bottom of the screen now.
[ "$(pixel at-left 700 893)" = "$desk" ] || fail "the dock at the left is at the bottom too"
# Its menu is beside it there, by the app.
move 30 450
click right
sleep 0.6
shot left-menu
[ "$(magick "$out/left-menu.png" "$out/at-left.png" -compose difference -composite -crop 240x130+80+390 +repage -format '%[fx:maxima > 0.3]' info:)" = 1 ] || fail "no menu beside the dock at the left"
key Escape
sleep 0.4
move 700 400

# One that hides is out of sight, over the window that has its place now, and
# comes with the pointer at its edge. Whether shot $1 has the app's icon, which
# has a color to it, in the middle of the bottom edge.
there() {
	[ "$(magick "$out/$1.png" -crop 44x44+678+834 +repage -format '%[fx:mean.r - mean.b > 0.01]' info:)" = 1 ]
}
there kept || fail "the app's icon has no color to tell it by"
settings '{ "dock": { "on": true, "pinned": ["kitty"], "autoHide": true } }'
move 700 400
sleep 1.5
shot hidden
there hidden && fail "a dock that hides stays in sight"
move 700 899
sleep 0.8
shot back
there back || fail "the edge of the screen doesn't bring the dock"
# Out of sight it takes no clicks from the window that's there: with another
# window beside the first, a click where the dock was goes to the one under it.
move 700 400
sleep 1.2
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --class okaeri-other --config NONE -o confirm_os_window_close=0 sleep 60 &
second=$!
sleep 1.5
[ "$(focused)" = okaeri-other ] || fail "the window beside the first isn't in focus: $(focused)"
move 670 870
click
sleep 0.5
[ "$(focused)" = kitty ] || fail "a dock out of sight took a click meant for the window under it"
kill "$second"
wait "$second" 2>/dev/null || true
move 700 400
sleep 0.5
# niri's overview brings it too, and takes it away again.
sleep 0.8
niri msg action toggle-overview
sleep 0.8
shot overview
there overview || fail "the overview doesn't bring a dock that hides"
niri msg action toggle-overview
sleep 1.2
shot overview-gone
there overview-gone && fail "a dock that hides stays after the overview"
# With smartHide it's in sight on an empty workspace, and hides again over a
# window.
settings '{ "dock": { "on": true, "pinned": ["kitty"], "autoHide": true, "smartHide": true } }'
niri msg action focus-workspace 2
move 700 400
sleep 1.2
shot bare
there bare || fail "a dock that hides is out of sight on an empty workspace"
niri msg action focus-workspace 1
sleep 1.4
shot not-bare
there not-bare && fail "a dock that hides stays in sight over a window"
settings '{ "dock": { "on": true, "pinned": ["kitty"], "autoHide": true } }'

# Kept by a call, and let go by one, as a script would.
ipc dock pin okaeri-test
sleep 0.3
[ "$(jq -c .dock.pinned "$own")" = '["kitty","okaeri-test"]' ] || fail "kept by a call: $(jq -c .dock.pinned "$own")"
ipc dock unpin okaeri-test
sleep 0.3
[ "$(jq -c .dock.pinned "$own")" = '["kitty"]' ] || fail "let go by a call: $(jq -c .dock.pinned "$own")"

# A screen that's to have none has none.
screen=$(niri msg --json outputs | jq -r 'keys[0]')
settings "{ \"dock\": { \"on\": true, \"pinned\": [\"kitty\"], \"hideOn\": [\"$screen\"] } }"
wait_layers 0 "on a screen that's to have none"
settings '{ "dock": { "on": true, "pinned": ["kitty"] } }'
wait_layers 1 "back on its screen"

# With only the apps it keeps, another app's window leaves it as it is, and with
# all of them it's there again.
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --class okaeri-other --config NONE -o confirm_os_window_close=0 sleep 60 &
second=$!
sleep 1.5
settings '{ "dock": { "on": true, "pinned": ["kitty"], "windows": "pinned" } }'
sleep 0.8
move 700 400
shot only-kept
set -- $(ends only-kept)
[ $(($2 - $1)) -lt $((one + 10)) ] || fail "an app it doesn't keep is on a dock for those it keeps: $1 to $2"
settings '{ "dock": { "on": true, "pinned": ["kitty"] } }'
sleep 0.8
shot all-again
set -- $(ends all-again)
[ $(($2 - $1)) -gt $((one + 30)) ] || fail "another app's window isn't on a dock for all of them: $1 to $2"
kill "$second"
wait "$second" 2>/dev/null || true

# An app's window on another workspace comes to this one from its menu, the
# first row there for an app this machine doesn't know.
niri msg action focus-workspace 2
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --class okaeri-away --config NONE -o confirm_os_window_close=0 sleep 60 &
away=$!
sleep 1.5
niri msg action focus-workspace 1
sleep 0.8
move 700 400
shot away
set -- $(ends away)
move $(($2 - one / 2)) 862
click right
sleep 0.6
key Down
key Return
sleep 0.6
here=$(niri msg --json workspaces | jq '.[] | select(.is_focused) | .id')
[ "$(niri msg --json windows | jq '.[] | select(.app_id == "okaeri-away") | .workspace_id')" = "$here" ] || fail "a window on another workspace wasn't brought here"
kill "$away"
wait "$away" 2>/dev/null || true
sleep 0.5

kill "$first"
wait "$first" 2>/dev/null || true
settings '{}'
wait_layers 0 "turned off"

echo "dock: all good" >&2
