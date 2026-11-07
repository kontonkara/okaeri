# The clipboard history, with wl-copy in the inner session: text of every
# kind, a picture, the filter, putting back, removing, the cap, the list that
# stays put, a large scale, and the watchers. Sourced by part.sh.

db=$XDG_STATE_HOME/okaeri/clipboard/history.db
pictures=$XDG_RUNTIME_DIR/okaeri/clipboard
canary=$XDG_RUNTIME_DIR/canary
files=$XDG_RUNTIME_DIR/files
mkdir -p "$files"

fail() {
	echo "clipboard: $1" >&2
	exit 1
}
entries() {
	cliphist -db-path "$db" list 2>/dev/null || true
}
count_is() {
	[ "$(entries | wc -l)" = "$1" ] || fail "$(entries | wc -l) entries, not $1"
}
wait_entry() {
	for _ in $(seq 50); do
		entries | grep -qF -- "$1" && return 0
		sleep 0.1
	done
	fail "\"$1\" didn't get to the history"
}
wait_gone() {
	for _ in $(seq 50); do
		entries | grep -qF -- "$1" || return 0
		sleep 0.1
	done
	fail "\"$1\" is still in the history"
}
# wait_new looks at the log from the last mark on.
mark() {
	seen=$(log | wc -l)
}
wait_new() {
	for _ in $(seq 50); do
		log | tail -n "+$((seen + 1))" | grep -qF -- "okaeri: clipboard: $1" && return 0
		sleep 0.1
	done
	fail "no \"$1\" in the log"
}
is_open() {
	niri msg layers | grep -q okaeri-panel
}
wait_closed() {
	for _ in $(seq 30); do
		is_open || return 0
		sleep 0.1
	done
	fail "the panel stayed open"
}
open_panel() {
	is_open && fail "the panel was already open"
	ipc clipboard toggle
	for _ in $(seq 30); do
		is_open && break
		sleep 0.1
	done
	is_open || fail "the panel didn't open"
	sleep 0.5
}
close_panel() {
	key Escape
	wait_closed
}
copy() {
	printf '%s' "$1" | wl-copy
	wait_entry "$2"
}
# The clipboard holds FILE, to the byte.
pasted_is() {
	sleep 0.3
	wl-paste -n >"$files/pasted"
	cmp "$files/pasted" "$1" || fail "the clipboard isn't $1"
}
pixel() {
	magick "$out/$1.png" -crop "1x1+$2+$3" -format '%[hex:p{0,0}]' info: | cut -c 1-6
}
# How many pixels of the rectangle WxH+X+Y differ between two shots, more than
# a preview drawn again does.
apart() {
	{ magick compare -metric AE -fuzz 3% -extract "$3" "$out/$1.png" "$out/$2.png" null: 2>&1 || true; } | cut -d ' ' -f 1
}
same() {
	[ "$(apart "$@")" = 0 ] || fail "$1 and $2 differ in $3: $(apart "$@")"
}
# Rows straight into the history, the last one newest.
fill() {
	cliphist -db-path "$db" wipe
	for n in $(seq "$1"); do
		printf '%s %02d' "$2" "$n" | cliphist -db-path "$db" store
	done
}
# The arrow down, N times in one go.
down() {
	wtype $(printf -- '-k Down %.0s' $(seq "$1"))
	sleep 0.5
}
# The watchers among the shell's children, a line each: pid and arguments.
watchers() {
	for pid in $(cat /proc/"$qs_pid"/task/*/children); do
		command=$(tr '\0' ' ' </proc/"$pid"/cmdline)
		case $command in
		*wl-paste\ *) echo "$pid ${command#*wl-paste }" ;;
		esac
	done
}

# They're there, and wl-paste runs cliphist as it is: that's what keeps what a
# password manager marks sensitive out.
for _ in $(seq 50); do
	[ "$(watchers | wc -l)" = 2 ] && break
	sleep 0.1
done
for type in text image; do
	watchers | grep -qF " --type $type --watch cliphist -db-path $db -max-items 750 -max-dedupe-search 750 store " ||
		fail "the $type watcher isn't what it should be: $(watchers)"
done
sleep 0.5

# What a watcher's cliphist does with a marked copy.
printf 'hunter2' | CLIPBOARD_STATE=sensitive cliphist -db-path "$db" store
[ -z "$(entries | grep -F hunter2)" ] || fail "cliphist stored something sensitive"
[ "$(stat -c %a "${db%/*}")" = 700 ] || fail "the history's directory isn't private"

# An empty history says so.
open_panel
shot empty
close_panel

# Text of every kind, and a picture.
copy 'plain text one' 'plain text one'
printf 'He said "it'"'"'s" $(touch %s) `touch %s`\n\tand a second line\n\n' "$canary" "$canary" >"$files/tricky"
wl-copy <"$files/tricky"
wait_entry 'He said'
magick -size 320x180 gradient:'#ff00aa-#2200ff' -fill white -draw 'circle 160,90 160,50' "$files/picture.png"
wl-copy --type image/png <"$files/picture.png"
wait_entry '[[ binary data'
copy '<b>bold</b> <img src="file:///nowhere.png"> and <i>more</i>' 'nowhere.png'
long=$(printf 'all work and no play %.0s' $(seq 30))
copy "$long" 'all work and no play'
copy 'zebra stripes' 'zebra stripes'
[ "$(entries | head -n 1 | cut -f 2)" = 'zebra stripes' ] || fail "the newest isn't first"

# All of it on screen: the picture's row is the fourth, and its preview is
# there, in color, with the file gone again.
mark
open_panel
wait_new '6 entries'
shot list
color=$(pixel list 1046 242)
case $color in
000000 | 111111 | 222222 | FFFFFF) fail "no preview: $color" ;;
esac
[ -z "$(find "$pictures" -type f 2>/dev/null)" ] || fail "a decoded picture stayed in $pictures"

# The same in the light theme.
printf '{"extends":"light"}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5
shot list-light
close_panel

# Typing filters with the list in front, Enter puts the entry back and closes.
mark
open_panel
type zeb
wait_new '1 entry'
shot filter-light
key Return
wait_closed
printf 'zebra stripes' >"$files/zebra"
pasted_is "$files/zebra"
printf '{"extends":"dark"}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5

# Quotes, $(...), backticks and newlines come back to the byte, and nothing ran
# them. Here by a click on the only row left.
mark
open_panel
type 'He said'
wait_new '1 entry'
move 1106 121
click
wait_closed
pasted_is "$files/tricky"
[ ! -e "$canary" ] || fail "something ran what was copied"
wl-paste --list-types | grep -qxF 'text/plain' || fail "text didn't come back as text"

# A filter that matches nothing, undone, and the picture found by Enter from
# the field.
mark
open_panel
type qqq
wait_new '0 entries'
shot no-match
key BackSpace
key BackSpace
key BackSpace
wait_new '6 entries'
type image
wait_new '1 entry'
shot filter-picture
key Return
wait_closed

# It comes back as a picture, to the byte, and first, once.
sleep 0.3
wl-paste --list-types | grep -qxF 'image/png' || fail "the picture isn't offered as one"
wl-paste --type image/png >"$files/pasted"
cmp "$files/pasted" "$files/picture.png" || fail "the picture changed"
sleep 0.3
entries | head -n 1 | grep -qF '[[ binary data' || fail "the picture isn't first again"
count_is 6

# Delete takes the row the arrows are on, only that one, and the next one
# moves up under them.
second=$(entries | sed -n 2p | cut -f 2-)
third=$(entries | sed -n 3p | cut -f 2-)
mark
open_panel
key Down
shot second-row
key Delete
wait_new '5 entries'
wait_gone "$second"
count_is 5
is_open || fail "Delete closed the panel"
key Delete
wait_new '4 entries'
wait_gone "$third"
count_is 4

# In the filter Delete is the text's.
type ab
key Left
key Delete
sleep 0.3
count_is 4
shot field-delete
close_panel

# Up from the first row takes the keys there too, and Down back to the list.
second=$(entries | sed -n 2p | cut -f 2-)
mark
open_panel
key Up
key Delete
sleep 0.3
count_is 4
shot field-focus
key Down
key Delete
wait_new '3 entries'
wait_gone "$second"
close_panel

# The trash button of the row under the pointer.
first=$(entries | sed -n 1p | cut -f 2-)
mark
open_panel
move 1206 128
shot hover
move 1365 128
click
wait_new '2 entries'
wait_gone "$first"
close_panel

# A click elsewhere closes, and so does the toggle.
open_panel
move 400 500
click
wait_closed
open_panel
ipc clipboard toggle
wait_closed

# More than the cap: it says so. The arrows scroll, with the pointer resting
# over the list, which doesn't take the row from them; a click puts back what's
# under it then. wlrctl's scroll is a touchpad's with no time passing, which
# Flickable drops: the wheel can't be tried here.
for n in $(seq 130); do
	printf 'filler number %03d' "$n" | cliphist -db-path "$db" store
done
count_is 132
mark
open_panel
wait_new 'Newest 100 of 132'
shot capped
move 1206 300
wtype -k Down -k Down -k Down -k Down -k Down -k Down -k Down -k Down -k Down -k Down -k Down -k Down -k Down -k Down
sleep 0.5
shot capped-keys
click
wait_closed
sleep 0.3
pasted=$(wl-paste -n)
case $pasted in
'filler number 125') fail "the list didn't scroll" ;;
'filler number '*) ;;
*) fail "a click on a filler row put back something else" ;;
esac
sleep 0.3
count_is 132

# Delete pressed quickly takes all it's pressed on.
open_panel
mark
wtype -k Delete -k Delete -k Delete
wait_new 'Newest 100 of 129'
sleep 0.5
count_is 129
close_panel

# The filter gets at what the cap leaves out, and that comes back undoubled.
mark
open_panel
type 'number 002'
wait_new '1 entry'
key Return
wait_closed
printf 'filler number 002' >"$files/filler"
pasted_is "$files/filler"
sleep 0.3
count_is 129
entries | head -n 1 | grep -qF 'filler number 002' || fail "the old entry isn't first"

# Tab gets to Clear all, which empties the history and says so.
mark
open_panel
wait_new 'Newest 100 of 129'
key Tab
shot clear-focus
close_panel
mark
open_panel
move 1076 563
click
wait_new '0 entries'
sleep 0.3
[ -z "$(entries)" ] || fail "Clear all left something"
shot cleared
close_panel

# So does the IPC call, and the clipboard goes with it.
copy 'one more' 'one more'
ipc clipboard clear
wait_gone 'one more'
sleep 0.3
wl-paste -n >/dev/null 2>&1 && fail "the clipboard still has what was cleared"

# A watcher that dies comes back with nothing cleared, and copying works again.
kill "$(watchers | grep -F -- ' --type text ' | cut -d ' ' -f 1)"
sleep 1
[ "$(watchers | wc -l)" = 1 ] || fail "the watcher didn't die"
for _ in $(seq 80); do
	[ "$(watchers | wc -l)" = 2 ] && break
	sleep 0.1
done
[ "$(watchers | wc -l)" = 2 ] || fail "the watcher didn't come back"
sleep 0.5
count_is 0
copy 'after the restart' 'after the restart'

# The trash in a lower row: the next row comes up under the pointer, a second
# click takes that one, and the clipboard has nothing to do with it.
fill 6 row
printf 'on the clipboard' >"$files/current"
wl-copy <"$files/current"
wait_entry 'on the clipboard'
open_panel
move 1206 197
move 1365 197
mark
click
wait_new '6 entries'
wait_gone 'row 05'
click
wait_new '5 entries'
wait_gone 'row 04'
is_open || fail "the trash closed the panel"
close_panel
pasted_is "$files/current"

# Under the last row it's the row below the list that comes up, and a click on
# what's there now takes nothing.
fill 3 row
open_panel
move 1206 197
move 1365 197
mark
click
wait_new '2 entries'
wait_gone 'row 01'
shot last-row
click
sleep 0.3
count_is 2
is_open || fail "a click under the rows closed the panel"
close_panel

# A row whose id went away while the panel was open, by the same thing copied
# again, leaves the clipboard as it is.
cliphist -db-path "$db" wipe
copy 'copied twice' 'copied twice'
copy 'then this' 'then this'
open_panel
copy 'copied twice' 'copied twice'
sleep 0.5
printf 'on the clipboard' | wl-copy
wait_entry 'on the clipboard'
move 1106 159
click
wait_closed
pasted_is "$files/current"

# Opening starts at the newest row, wherever the list was left and whichever
# row is under a pointer that moved while it was closed.
fill 40 row
open_panel
down 25
close_panel
move 1206 300
open_panel
shot reopened
key Return
wait_closed
printf 'row 40' >"$files/newest"
pasted_is "$files/newest"

# A row out of a scrolled list, by the key and by the trash: what's above it
# stays where it is, also in the first frames with the row gone, and the row
# under the keys is the next one. The arrows leave the list half a row in.
fill 40 row
open_panel
down 20
shot scrolled
mark
wtype -k Delete
for _ in $(seq 20); do
	shot scrolled-at-once
	[ "$(apart scrolled scrolled-at-once 356x38+1028+501)" = 0 ] || break
done
wait_new '39 entries'
wait_gone 'row 20'
sleep 0.5
shot scrolled-later
same scrolled scrolled-at-once 356x399+1028+102
same scrolled scrolled-later 356x399+1028+102
key Delete
wait_new '38 entries'
wait_gone 'row 19'
move 1206 300
move 1365 300
sleep 0.2
shot scrolled-hover
click
wait_new '37 entries'
wait_gone 'row 26'
sleep 0.5
shot scrolled-trash
same scrolled-hover scrolled-trash 356x171+1028+102
click
wait_new '36 entries'
wait_gone 'row 25'
close_panel

# At the end of the list the rows above come down, and the last one stays
# under the keys.
fill 30 row
open_panel
down 29
mark
key Delete
wait_new '29 entries'
wait_gone 'row 01'
key Delete
wait_new '28 entries'
wait_gone 'row 02'
sleep 0.5
shot end-of-list
close_panel

# The same with taller rows among them, which ListView has to guess at.
cliphist -db-path "$db" wipe
for n in $(seq 40); do
	if [ "$((n % 4))" = 0 ]; then
		magick -size 64x48 "xc:rgb($((n * 6)),90,200)" "$files/tile.png"
		cliphist -db-path "$db" store <"$files/tile.png"
	else
		printf 'row %02d' "$n" | cliphist -db-path "$db" store
	fi
done
open_panel
down 20
sleep 0.5
shot mixed
mark
key Delete
wait_new '39 entries'
sleep 1
shot mixed-later
same mixed mixed-later 356x385+1028+102

# Rows that go as soon as they came, while they decode, leave no picture. Each
# Delete makes the top rows and drops them, and each key of the filter all rows.
wtype -k Delete -k Delete -k Delete -k Delete -k Delete -k Delete -k Delete -k Delete
for _ in 1 2 3 4 5 6; do
	wtype image -k BackSpace -k BackSpace -k BackSpace -k BackSpace -k BackSpace
done
sleep 1
close_panel
sleep 0.5
[ -z "$(find "$pictures" -type f 2>/dev/null)" ] || fail "rows that went left a picture in $pictures"

# cliphist can't tell a WebP is a picture, and shows its bytes as text: it comes
# back as what it is all the same.
magick -size 64x64 xc:orange "$files/picture.webp"
wl-copy --type image/webp <"$files/picture.webp"
wait_entry 'WEBP'
open_panel
key Return
wait_closed
sleep 0.3
wl-paste --list-types | grep -qxF 'image/webp' || fail "the WebP isn't offered as one"
wl-paste --type image/webp >"$files/pasted"
cmp "$files/pasted" "$files/picture.webp" || fail "the WebP changed"

# A list that fails changes nothing: a locked history isn't an empty one.
open_panel
close_panel
mark
flock -x "$db" sleep 2 &
locker=$!
sleep 0.2
open_panel
sleep 1
shot locked
log | tail -n "+$((seen + 1))" | grep -qF 'okaeri: clipboard: 0 entries' && fail "a locked history came out empty"
close_panel
wait "$locker"

# At a large scale the list gives way: the card ends above the edge of the
# screen, with Clear all on it, and with rows there the theme can change.
open_panel
printf '{"scale":1.5}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5
printf '{"scale":2}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.8
shot large
[ "$(pixel large 1206 897)" != 000000 ] || fail "the card goes off the screen"
close_panel
open_panel
shot large-open
[ "$(pixel large-open 1206 897)" != 000000 ] || fail "the card goes off the screen when opened"
close_panel
printf '{"extends":"dark"}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5

# Pinned: first in the list, and it stays when the history goes.
pinned=$XDG_STATE_HOME/okaeri/clipboard/pins/pins.json
pin_key() {
	wtype -M ctrl -k p -m ctrl
	sleep 0.5
}
copy 'a pin for later' 'a pin for later'
open_panel
pin_key
[ "$(jq length "$pinned")" = 1 ] || fail "not pinned: $(cat "$pinned" 2>/dev/null)"
key Escape
wait_closed
copy 'newer than the pin' 'newer than the pin'
open_panel
shot pinned
key Return
wait_closed
sleep 0.3
[ "$(wl-paste -n)" = 'a pin for later' ] || fail "the pin isn't first: $(wl-paste -n)"
ipc clipboard clear
sleep 0.5
count_is 0
open_panel
key Return
wait_closed
sleep 0.3
[ "$(wl-paste -n)" = 'a pin for later' ] || fail "the pin went with the history: $(wl-paste -n)"
# A picture, to the byte, and its file is the row's to keep.
magick -size 64x48 xc:'#336699' "$files/pinned.png"
wl-copy --type image/png <"$files/pinned.png"
sleep 0.5
wait_entry 'binary data'
open_panel
key Down
pin_key
[ "$(jq length "$pinned")" = 2 ] || fail "the picture isn't pinned: $(cat "$pinned")"
key Escape
wait_closed
ipc clipboard clear
sleep 0.5
open_panel
sleep 0.5
shot pinned-picture
key Return
wait_closed
sleep 0.5
wl-paste --type image/png >"$files/pasted.png"
cmp "$files/pinned.png" "$files/pasted.png" || fail "the pinned picture came back changed"

# Only text or only pictures, by the two buttons beside the filter.
copy 'some more text' 'some more text'
mark
open_panel
move 1321 73
click
wait_new "2 entries"
move 1365 73
click
wait_new "1 entry"
shot only-pictures
close_panel

# Unpinned by the key: gone with its file.
open_panel
pin_key
key Escape
wait_closed
[ "$(jq length "$pinned")" = 1 ] || fail "not unpinned: $(cat "$pinned")"
[ "$(find "$(dirname "$pinned")" -type f | wc -l)" = 2 ] || fail "a pin's file stayed: $(ls "$(dirname "$pinned")")"

# Pasted into the window in focus, a terminal here: Shift+Enter, and Enter with the
# setting on. Enter alone only copies.
DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 sh -c "cat >$files/typed" &
terminal=$!
sleep 1.5
copy 'pasted by shift' 'pasted by shift'
open_panel
type 'pasted by shift'
wtype -M shift -k Return -m shift
wait_closed
sleep 0.6
key Return
copy 'only copied' 'only copied'
open_panel
type 'only copied'
key Return
wait_closed
sleep 0.6
key Return
printf '{ "clipboard": { "paste": true } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.5
copy 'pasted by enter' 'pasted by enter'
open_panel
type 'pasted by enter'
key Return
wait_closed
sleep 0.6
key Return
sleep 0.3
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
kill "$terminal"
wait "$terminal" 2>/dev/null || true
[ "$(cat "$files/typed")" = "$(printf 'pasted by shift\n\npasted by enter')" ] || fail "in the window: $(cat "$files/typed")"

# Nothing that was copied is in the log, and no picture stayed.
for text in hunter2 zebra 'He said' 'filler number' 'after the restart'; do
	log | grep -qF "$text" && fail "\"$text\" is in the log"
done
[ -z "$(find "$pictures" -type f 2>/dev/null)" ] || fail "a decoded picture stayed in $pictures"

# The watchers end with the shell, even one killed, and nothing goes on storing.
pids=$(watchers | cut -d ' ' -f 1)
kill -9 "$qs_pid"
sleep 1
for pid in $pids; do
	[ ! -e "/proc/$pid" ] || fail "a watcher outlived the shell"
done
copied=$(entries | wc -l)
printf 'after the shell' | wl-copy
sleep 0.5
count_is "$copied"
echo "clipboard: all good"
