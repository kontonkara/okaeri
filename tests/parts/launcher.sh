# Drives the launcher with real keys and the pointer. What it launches shows as
# dry lines in the log. The apps are this machine's own: a test can't hand the
# shell others, so the queries below name apps that are here, up to the end,
# where a stand-in for them comes in.

fail() {
	echo "launcher: $1" >&2
	exit 1
}

launches() {
	log | sed -n 's/.*okaeri: dry: launch //p'
}

seen=0

# The next launch was $1, and the only one.
launched() {
	seen=$((seen + 1))
	for _ in $(seq 20); do
		[ "$(launches | wc -l)" -ge "$seen" ] && break
		sleep 0.1
	done
	got=$(launches | sed -n "${seen}p")
	[ "$got" = "$1" ] || fail "wanted a launch of $1, got \"$got\""
	[ "$(launches | wc -l)" -eq "$seen" ] || fail "launched more than $1: $(launches | tail -n 1)"
	sleep 0.2
}

nothing_launched() {
	sleep 0.3
	[ "$(launches | wc -l)" -eq "$seen" ] || fail "launched $(launches | tail -n 1)"
}

open() {
	ipc launcher toggle
	sleep 0.3
}

# Opens it and launches the first row for query $1, which has to be app $2.
pick() {
	open
	type "$1"
	key Return
	launched "$2"
}

# Key $1, $2 times.
press() {
	for _ in $(seq "$2"); do
		key "$1"
	done
}

# Where row $1 of the panel is on the 1400x900 screen.
row() {
	echo $((312 + 46 * $1))
}

# To a place as a hand gets there: move jumps, in one event, and it takes the
# next ones for the rows to hear of the pointer.
glide() {
	move "$1" "$2"
	wlrctl pointer move 1 0
	wlrctl pointer move 1 0
	sleep 0.1
}

# A point in the card's corner: what's there tells whether the panel is up.
corner() {
	shot corner
	magick "$out/corner.png" -format '%[pixel:p{930,610}]' info:
}

is_closed() {
	sleep 0.3
	[ "$(corner)" = "$screen" ] || fail "$1: the panel is still there"
}

# A picture of the rows alone, and whether two of them show the same.
rows() {
	shot "$1"
	magick "$out/$1.png" -crop 500x300+450+295 +repage "$out/$1-rows.png"
}

same() {
	magick compare -metric AE -fuzz 5% "$out/$1-rows.png" "$out/$2-rows.png" null: 2>/dev/null
}

screen=$(corner)

# The pointer rests on the third row all along here. Rows that come up under it
# must not take the selection from the keys: "vi" has others above it.
move 700 "$(row 2)"
open
[ "$(corner)" != "$screen" ] || fail "toggle didn't open it"
shot open
type vi
shot typed
key Return
launched vim
is_closed "Enter"

# Ranks: exact, prefix, then word starts, then letters in order.
pick vim vim
pick fire firefox
pick FIRE firefox
pick te org.telegram.desktop
pick password org.keepassxc.KeePassXC
pick tg org.telegram.desktop
pick lizard dev.lizardbyte.app.Sunshine
pick ktty kitty

# The exchange rates are fetched from the start.
wait_log "okaeri: dry: exchange rates"

# A sum comes first, and Enter copies the answer.
copies() {
	log | sed -n "s/.*okaeri: dry: copy //p"
}
copied=0
copied() {
	copied=$((copied + 1))
	for _ in $(seq 20); do
		[ "$(copies | wc -l)" -ge "$copied" ] && break
		sleep 0.1
	done
	got=$(copies | sed -n "${copied}p")
	[ "$got" = "$1" ] || fail "wanted a copy of \"$1\", got \"$got\""
	nothing_launched
}
sum() {
	open
	type "$1"
	sleep 0.2
	key Return
	copied "$2"
	is_closed "a sum"
}
no_sum() {
	open
	type "$1"
	sleep "${2:-0.2}"
	key Return
	sleep 0.2
	[ "$(copies | wc -l)" -eq "$copied" ] || fail "$1 is a sum: $(copies | tail -n 1)"
	nothing_launched
	key Escape
	is_closed "not a sum"
}
open
type "2+2"
sleep 0.2
shot sum
key Return
copied 4
is_closed "a sum"
sum "(1+2)*3" 9
sum "-5+3" -2
sum "150*20%" 30
sum "5 km to m" "5000 m"
sum "sqrt(16)" 4
sum "/calc 6*7" 42

# An open window, under the apps: Enter goes to it.
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --title okaeri-first --config NONE -o confirm_os_window_close=0 sleep 30 &
first_window=$!
sleep 1.5
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --title okaeri-second --config NONE -o confirm_os_window_close=0 sleep 30 &
second_window=$!
sleep 1.5
title() {
	niri msg --json focused-window | jq -r .title
}
[ "$(title)" = okaeri-second ] || fail "the second window isn't in focus: $(title)"
open
type okaeri-first
sleep 0.2
shot window-row
key Return
sleep 0.4
[ "$(title)" = okaeri-first ] || fail "Enter didn't go to the window: $(title)"
nothing_launched
kill "$first_window" "$second_window"
wait "$first_window" "$second_window" 2>/dev/null || true
sleep 0.4

# Apps stay apps, and a sum that won't end doesn't hold up the next.
no_sum 2048
no_sum "99999999!" 1.4
sum "1+1" 2
pick fire firefox
pick kpxc org.keepassxc.KeePassXC
# Telegram, launched by now, has "ra" inside a word, and other apps at a word's
# start; this one alone has "raw".
pick raw blackmagicraw-player
# An id goes in full too, or the start of it.
pick org.telegram.desktop org.telegram.desktop
pick dev.lizardbyte dev.lizardbyte.app.Sunshine

# Up and Down, with the keys still in the field.
open
type vim
key Down
key Return
launched gvim
open
type vim
key Up
key Down
key Up
key Return
launched vim
open
type vi
key Down
type m
key Return
launched vim
open
type vi
key Tab
type m
key Return
launched vim

# A rank isn't bought with launches: GVim has them, Vim's exact.
open
type vim
key Down
key Return
launched gvim
pick vim vim

# Hidden entries, and nothing to launch.
open
type "kitty url"
key Return
nothing_launched
press BackSpace 9
type qqzz
shot empty
key Return
nothing_launched

# Escape closes, and the next time the field is empty again.
key Escape
is_closed "Escape"
type fire
key Return
nothing_launched
pick kitty kitty

# The toggle closes too.
open
ipc launcher toggle
is_closed "toggle"

# The pointer: a move gives it the selection, Enter then goes by it.
open
type vi
glide 700 "$(row 1)"
shot hover
key Return
launched virt-manager

# The keys take the selection back from it, typing or with Down.
open
type v
glide 700 "$(row 2)"
type i
key Return
launched vim
open
type vi
glide 700 "$(row 0)"
key Down
key Return
launched virt-manager

# A small move on the row the pointer was resting on is enough.
move 700 "$(row 2)"
open
type vi
wlrctl pointer move 2 2
wlrctl pointer move 2 2
sleep 0.2
key Return
launched code

# A click on a row, the pointer moved or not.
open
type vi
glide 700 "$(row 2)"
click
launched code
open
type vi
click
launched code

# The rows take clicks as the panel fades: a double click still launches once,
# and so does a click right after Enter.
open
type fire
glide 700 "$(row 0)"
wlrctl pointer click left
wlrctl pointer click left
sleep 0.3
launched firefox
open
type fire
wtype -k Return
wlrctl pointer click left
sleep 0.3
launched firefox

# A click in the field isn't a click elsewhere, one outside is.
move 700 261
open
click
type fire
key Return
launched firefox
move 100 500
open
click
is_closed "a click outside"

# Down past the last row in sight scrolls the list, under a pointer at rest, Up
# brings it back, and so do typing and opening it again.
move 700 "$(row 3)"
open
rows list-top
press Down 10
rows list-down
same list-top list-down && fail "Down didn't scroll the list"
press Up 10
rows list-up
same list-top list-up || fail "Up didn't bring the list back"
press Down 10
key Escape
is_closed "Escape from far down"
open
rows list-again
same list-top list-again || fail "it opened where it was left"
press Down 10
type fire
shot list-typed
key Return
launched firefox

# Equals go by launches: Code has them, the other "Studio"s not.
pick studio code

# As it looks in the light theme, with the corners square, and without the
# animations.
echo '{"extends":"light"}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5
open
shot light-open
type vi
key Down
shot light-typed
press BackSpace 2
type qqzz
shot light-empty
key Escape
is_closed "Escape in the light theme"

echo '{"radius":0,"animations":false}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5
open
type vi
shot square
key Escape
is_closed "Escape without animations"

echo '{}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5

# What was launched is in the file, as many times as it was.
state=$XDG_STATE_HOME/okaeri/launches.json
for app in $(jq -r 'keys[]' "$state"); do
	[ "$(jq --arg app "$app" '.[$app]' "$state")" = "$(launches | grep -cFx "$app")" ] ||
		fail "$app: $(jq -c . "$state") isn't what the log says"
done
[ "$(jq '[.[]] | add' "$state")" -eq "$seen" ] || fail "the file has other than $seen launches"

# The shell reloads as its copy changes, and what it remembers it reads anew:
# without a query the most launched comes first, the pointer on another row.
# This machine has too few apps to reach the limit on the rows: so it's less.
top=$(jq -r 'to_entries | max_by(.value) | .key' "$state")
limited=$(sed 's/limit: 50/limit: 3/' "$work/shell/launcher/Apps.qml")
printf '%s\n' "$limited" >"$work/shell/launcher/Apps.qml"
wait_log 'Reloading configuration'
move 700 "$(row 2)"
ipc launcher toggle
sleep 0.3
shot ranked
key Return
launched "$top"

move 100 500
open
shot limit
[ "$(magick "$out/limit.png" -crop 500x170+450+440 +repage -format '%[fx:maxima]' info:)" = 0 ] ||
	fail "more rows than the limit"
key Escape
is_closed "Escape at the end"

# Apps that come and go, and icons that aren't there. This machine's stay as
# they are, so in the shell's copy a stand-in takes the place of DesktopEntries,
# told by calls what there is.
cat >"$work/shell/launcher/Entries.qml" <<'QML'
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
	id: entries

	property var applications: ({ values: [] })

	IpcHandler {
		target: "entries"

		function add(id: string, name: string, icon: string): void {
			const actions = [{ id: "second", name: "Second Thing", icon: "nosuchicon", command: ["second"] }];
			const entry = { id, name, icon, actions, genericName: "", comment: "", keywords: [] };
			entries.applications = { values: [...entries.applications.values, entry] };
		}

		function remove(id: string): void {
			entries.applications = { values: entries.applications.values.filter(entry => entry.id !== id) };
		}
	}
}
QML
# A lot of launches, for further down.
often=$(jq -c '. + { "zz.frequent": 40 }' "$state")
printf '%s\n' "$often" >"$state"
stood_in=$(sed -e 's/DesktopEntries/Entries/g' -e 's/limit: 3/limit: 50/' "$work/shell/launcher/Apps.qml")
printf '%s\n' "$stood_in" >"$work/shell/launcher/Apps.qml"
for _ in $(seq 100); do
	ipc entries add org.example.Zebra Zebra nosuchicon 2>&1 | grep -qE 'Not ready|not found' || break
	sleep 0.1
done

mkdir "$work/with#hash"
magick -size 18x18 xc:red "$work/with#hash/red.png"
cp "$work/with#hash/red.png" "$work/red.png"
ipc entries add dotted.Thing Stripes nosuchicon
ipc entries add icon.file "Icon File" "$work/red.png"
ipc entries add icon.hash "Icon Hash" "$work/with#hash/red.png"
ipc entries add icon.none "Icon None" "$work/nowhere.png"

# An id in full, its start, and the first part of one that isn't reverse-DNS.
pick org.example.zebra org.example.Zebra
pick org.example org.example.Zebra
pick dotted dotted.Thing

# A file for an icon, wherever it is, and the icon of any app if it's not there.
move 100 500
open
type icon
shot icons
for index in 0 1; do
	[ "$(magick "$out/icons.png" -format "%[pixel:p{435,$(row "$index")}]" info:)" = "srgb(255,0,0)" ] ||
		fail "row $index doesn't have its file for an icon"
done
[ "$(magick "$out/icons.png" -crop 26x26+422+$(($(row 2) - 13)) +repage -format '%[fx:maxima]' info:)" != 0 ] ||
	fail "an icon that isn't there left nothing in its place"
key Escape
is_closed "Escape over the icons"

# A name is only text, whatever it looks like.
ipc entries add odd.Markup '<font color="#ff0000">Reddish</font>' nosuchicon
open
type reddish
shot markup
magick "$out/markup.png" -crop 400x30+458+$(($(row 0) - 15)) +repage -channel RG -separate +channel \
	-compose difference -composite -format '%[fx:maxima]' info: | awk '{ exit !($1 < 0.4) }' ||
	fail "a name was taken for markup"
key Escape
is_closed "Escape over the name"
ipc entries remove odd.Markup

# What's gone with the panel open can't be launched, what's new can, and the
# keys stay in the field through it.
open
type zebra
ipc entries remove org.example.Zebra
sleep 0.2
shot gone
key Return
nothing_launched
key Escape
is_closed "Escape over no apps"
open
type newcomer
ipc entries add newcomer.app Newcomer nosuchicon
sleep 0.2
shot new
key Return
launched newcomer.app

# The selection stays on its app as another comes in above it, and goes to the
# first row with it when it's gone.
open
type icon
key Down
ipc entries add icon.above "Icon Above" nosuchicon
sleep 0.2
key Return
launched icon.hash
open
type icon
key Down
ipc entries remove icon.above
sleep 0.2
key Return
launched icon.hash

# Two calls at once: the second closes what never got to show, and nothing
# stays up with the keys.
ipc launcher toggle &
first=$!
ipc launcher toggle
wait "$first"
sleep 0.5
niri msg --json layers | jq -e 'all(.[]; .namespace != "okaeri-panel")' >/dev/null ||
	fail "two calls at once left the panel up"

# A lot of launches pass a better fit, but never all of a name.
ipc entries add zz.frequent "Zz Often" nosuchicon
ipc entries add never.launched "Oftener" nosuchicon
ipc entries add whole.name "Often" nosuchicon
pick oft zz.frequent
pick often whole.name

# What else an app can do, by the pointer: its own first.
own=$XDG_STATE_HOME/okaeri/settings.json
shifted_enter() {
	wtype -M shift -k Return -m shift
	sleep 0.3
}
open
type "icon file"
glide 700 "$(row 0)"
click right
sleep 0.3
shot app-menu
key Down
key Return
launched "icon.file second"
is_closed "an action"

# By the keys, and Escape comes back from it to where it was: the second row,
# with Icon Hash ahead of it for its launches.
open
type icon
key Down
shifted_enter
shot app-menu-keys
key Escape
sleep 0.3
key Return
launched icon.file
# Back by its row, and typing goes back to searching.
open
type "icon file"
shifted_enter
key Return
sleep 0.3
key Return
launched icon.file
open
type "icon file"
shifted_enter
press BackSpace 1
type e
key Return
launched icon.file
# Enter in a field that doesn't tell Shift apart is still Enter: only here it's a menu.
open
type qqzz
shifted_enter
key Escape
is_closed "Shift+Enter with no row"

# Pinned: first without a query, in the order they came, and marked.
pin() {
	open
	type "$1"
	shifted_enter
	press Down 2
	key Return
	sleep 0.3
	key Escape
	is_closed "pinning $1"
}
pin "icon none"
pin "icon file"
[ "$(jq -c .launcher.pinned "$own")" = '["icon.none","icon.file"]' ] || fail "pinned: $(jq -c .launcher.pinned "$own")"
open
sleep 0.3
shot pinned
key Return
launched icon.none
open
key Down
key Return
launched icon.file
# A search goes by the fit all the same.
pick stripes dotted.Thing
pin "icon none"
[ "$(jq -c .launcher.pinned "$own")" = '["icon.file"]' ] || fail "unpinned: $(jq -c .launcher.pinned "$own")"

# Hidden: not searched for any more.
open
type "icon hash"
shifted_enter
press Down 3
key Return
sleep 0.3
shot hidden
[ "$(jq -c .launcher.hidden "$own")" = '["icon.hash"]' ] || fail "hidden: $(jq -c .launcher.hidden "$own")"
key Return
nothing_launched
key Escape
is_closed "after hiding"

# A / says what it can ask for, Enter takes it, and it narrows down as it's typed.
open
type /
shot modes
key Return
sleep 0.3
# The last sums, for their answers.
shot sums
key Return
copied 2
is_closed "a last sum"
[ "$(jq -r '.[0].expression' "$XDG_STATE_HOME/okaeri/sums.json")" = "1+1" ] ||
	fail "the last sum isn't kept: $(cat "$XDG_STATE_HOME/okaeri/sums.json")"
open
type /wi
key Return
sleep 0.2
key Escape
is_closed "/win"
sum "/calc 3*3" 9
open
type "/calc "
sleep 0.2
key Return
copied 9
is_closed "the newest sum"

# Only what it asks for: /win has no apps.
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --title icon-window --config NONE -o confirm_os_window_close=0 sleep 30 &
icon_window=$!
sleep 1.5
niri msg action focus-column-left 2>/dev/null || true
open
type "/win icon"
sleep 0.2
shot window-mode
key Return
sleep 0.4
[ "$(title)" = icon-window ] || fail "/win didn't go to the window: $(title)"
nothing_launched
kill "$icon_window"
wait "$icon_window" 2>/dev/null || true
sleep 0.4
open
type "/nope icon"
sleep 0.2
key Return
nothing_launched
key Escape
is_closed "what can't be asked for"

# Wallpapers by name, from where the settings say.
mkdir "$work/walls"
magick -size 64x36 xc:blue "$work/walls/blue sky.png"
magick -size 64x36 xc:green "$work/walls/green field.png"
printf '{ "wallpaper": { "folder": "%s/walls" } }\n' "$work" >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.5
open
type "/wall green"
sleep 0.4
shot wall-mode
key Return
sleep 0.3
[ "$(jq -r .wallpaper.path "$own")" = "$work/walls/green field.png" ] || fail "the wallpaper: $(jq -r .wallpaper.path "$own")"
is_closed "a wallpaper"

# Emoji and symbols by their names: Enter types and copies one, and the panel goes.
open
type "/emoji grinning"
sleep 0.3
shot emoji-mode
key Return
wait_log "okaeri: dry: emoji"
is_closed "an emoji"
open
type "/emoji euro"
sleep 0.3
shot symbol-mode
[ "$(magick "$out/symbol-mode.png" "$out/emoji-mode.png" -compose difference -composite -format '%[fx:maxima > 0.05]' info:)" = 1 ] || fail "the same for a symbol as for an emoji"
key Escape
is_closed "the symbols"

# Weight in the wheel and the touchpad, over a list long enough for them.
for number in $(seq 20); do
	ipc entries add "long.$number" "Longlist $number" nosuchicon
done
at() {
	ipc launcher scrolled
}
# Until it's at rest, and says where.
rest() {
	before=-1
	for _ in $(seq 40); do
		now=$(at)
		[ "$now" = "$before" ] && break
		before=$now
		sleep 0.1
	done
	echo "$now"
}
open
type longlist
glide 700 "$(row 3)"
[ "$(at)" = 0 ] || fail "it opened scrolled to $(at)"
# A notch glides there, it doesn't jump, and two add up.
notch 1
early=$(at)
one=$(rest)
awk "BEGIN { exit !($one > 80 && $one < 100) }" || fail "a notch went to $one"
awk "BEGIN { exit !($early < $one) }" || fail "a notch jumped there: $early of $one"
notch 1
notch 1
two=$(rest)
awk "BEGIN { exit !($two > $one * 2.5) }" || fail "two notches went to $two from $one"
# Back up, not past the top, and the keys are still in the field.
notch -8
[ "$(rest)" = 0 ] || fail "the wheel went past the top: $(at)"
# The fingers set it going and it keeps on after they've left, for a while.
swipe 300
left=$(at)
sleep 0.15
on=$(at)
awk "BEGIN { exit !($left > 100 && $on > $left) }" || fail "the fingers left it at $left, then it was at $on"
far=$(rest)
awk "BEGIN { exit !($far > $on) }" || fail "it stopped at once: $on, then $far"
key Escape
is_closed "Escape after scrolling"

# With no animations it all goes at once.
echo '{"animations":false}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5
open
type longlist
glide 700 "$(row 3)"
notch 1
sleep 0.05
early=$(at)
[ "$early" = "$(rest)" ] || fail "it glides without animations"
swipe 300
left=$(at)
sleep 0.3
[ "$left" = "$(at)" ] || fail "it goes on without animations"
key Escape
is_closed "Escape without animations again"
echo '{}' >"$XDG_CONFIG_HOME/okaeri/theme.json"

