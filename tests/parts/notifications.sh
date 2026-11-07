# The notifications part, driven by notify-send on the stand's private bus and
# by the real pointer and keys. With OKAERI_GUEST=1 in the environment it tries
# guest mode instead.

# Next to another shell: no server, and the rest still works.
if [ "${OKAERI_GUEST:-}" = 1 ]; then
	dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
		org.freedesktop.DBus.NameHasOwner string:org.freedesktop.Notifications | grep -q 'boolean false'
	ipc notifications toggle
	sleep 0.5
	ipc notifications state | jq -e '.panel and .history == 0' >/dev/null
	shot guest
	ipc notifications toggle
	return 0
fi

# 1400x900: the toasts and the panel start at 1016,42 and end at 1396.
toast_x=1206
top_close_x=1375
top_close_y=63
empty_toggle_y=212
# The top toast's picture.
tile=40x40+1030+56

# With a limit: one with actions waits for an answer.
send() {
	timeout 30 notify-send "$@"
}
step() {
	echo "notifications: $1" >&2
}
state() {
	ipc notifications state | jq -r ".$1"
}
# Until the state's FIELD is VALUE, or fails after TENTHS of a second.
wait_state() {
	for _ in $(seq "${3:-50}"); do
		[ "$(state "$1")" = "$2" ] && return 0
		sleep 0.1
	done
	echo "notifications: $1 is $(state "$1"), not $2" >&2
	return 1
}
is() {
	[ "$(state "$1")" = "$2" ] || {
		echo "notifications: $1 is $(state "$1"), not $2" >&2
		return 1
	}
}
# The color of a shot's pixel, as rrggbb.
pixel() {
	magick "$out/$1.png" -format "%[hex:p{$2,$3}]" info: | cut -c1-6 | tr 'A-F' 'a-f'
}
looks() {
	got=$(pixel "$1" "$2" "$3")
	[ "$got" = "$4" ] || {
		echo "notifications: $1.png at $2,$3 is $got, not $4" >&2
		return 1
	}
}
# A part of a shot, as a hash.
area() {
	magick "$out/$1.png" -crop "$2" +repage -format '%#' info:
}
stop_sender() {
	kill "$sender" 2>/dev/null || true
	wait "$sender" 2>/dev/null || true
}
# Two shots are the same in an area, but for a rounding here and there.
alike() {
	[ "$(magick "$out/$1.png" "$out/$2.png" -compose difference -composite -crop "$3" +repage -format '%[fx:maxima * 255 < 3]' info:)" = 1 ]
}
# Past the animations.
settle() {
	sleep 0.4
}
reset() {
	move 300 600
	ipc notifications clear
	wait_state toasts 0
	wait_state history 0
	settle
}

# From where the pointer is: part.sh's move would take it off what it's on.
move 300 600
at_x=300
at_y=600
move() {
	wlrctl pointer move "$(($1 - at_x))" "$(($2 - at_y))"
	at_x=$1
	at_y=$2
	sleep 0.1
}

# A picture and an icon, as apps send them.
magick -size 96x96 gradient:'#6688cc'-'#223366' "$out/picture.png"

# Nothing yet.
settle
shot empty
is history 0
is toasts 0
backdrop=$(pixel empty 1206 500)

# The very first: the entries load after its lookup, and it gets its icon then.
step "The first one"
send -a kitty "The first one" "From a desktop entry."
wait_state toasts 1
settle
shot first-lookup
reset
send -a Mail "The bell" "Nothing to show."
wait_state toasts 1
settle
shot bell-tile
bell=$(area bell-tile "$tile")
reset
if command -v kitty >/dev/null; then
	[ "$(area first-lookup "$tile")" != "$bell" ]
fi

# A normal one: it goes after the default timeout and stays in the history.
step "A normal one"
send -a Mail "Hello there" "A normal notification, with a body that is long enough to wrap onto a second line of the card."
wait_state toasts 1
settle
shot toast-normal
looks toast-normal "$toast_x" 90 000000
looks toast-normal "$toast_x" 300 "$backdrop"
niri msg --json layers | jq -e '.[] | select(.namespace == "okaeri-toasts") | select(.layer == "Overlay" and .keyboard_interactivity == "None")' >/dev/null
is unread 1
wait_state toasts 0 80
is history 1
settle
shot toast-gone
looks toast-gone "$toast_x" 90 "$backdrop"
niri msg --json layers | jq -e '[.[] | select(.namespace == "okaeri-toasts")] | length == 0' >/dev/null
reset

# An expiring one goes when its app said, and not before.
step "An expiring one"
send -a Clock -t 1200 "Expires" "In a little over a second."
wait_state toasts 1
sleep 0.5
is toasts 1
wait_state toasts 0 20
is history 1
reset

# It waits while the pointer is on it, and goes after it left.
step "Hover"
send -a Clock -t 800 "Hovered" "Stays while the pointer is on it."
wait_state toasts 1
move "$toast_x" 70
sleep 1.4
is toasts 1
move 300 600
wait_state toasts 0 20
reset

# A critical one stays past any timeout, and a right click closes it.
step "A critical one"
send -a Battery -u critical -t 500 "Battery low" "Plug it in."
wait_state toasts 1
sleep 1.2
is toasts 1
settle
shot toast-critical
move "$top_close_x" "$top_close_y"
# Twice: the second one finds it on its way out.
wlrctl pointer click right
wlrctl pointer click right
wait_state toasts 0
wait_state history 0
reset

# Actions: a button and the default action, through Env.act.
step "Actions"
send -a Files -A open=Open -A folder="Show in folder" "Download finished" "report.pdf" >/dev/null &
sender=$!
wait_state toasts 1
settle
shot toast-actions
move 1109 123
click
wait_log "okaeri: dry: notification action open"
stop_sender
reset
send -a Chat -A default=Reply "Someone wrote" "Click the toast." >/dev/null &
sender=$!
wait_state toasts 1
settle
shot toast-default
move 1206 80
click
wait_log "okaeri: dry: notification action default"
stop_sender
reset
# A label is text too: its tags show, and take up the whole button.
send -a Files -A 'open=<b>Bold</b> <font color="red">red</font>' "Download finished" "report.pdf" >/dev/null &
sender=$!
wait_state toasts 1
settle
shot toast-markup
[ "$(pixel toast-markup 1346 122)" != 000000 ]
stop_sender
reset

# Pictures: a file, an image hint, an icon nobody has. Markup stays text.
step "Pictures"
send -a Photos -i "$out/picture.png" "With an icon file" "From the app icon."
send -a kitty "From a desktop entry" "No icon of its own, its app has one."
send -a Photos -h "string:image-path:file://$out/picture.png" "With an image" "From the image hint."
send -a Mail -i no-such-icon-anywhere "With a missing icon" "<b>Bold</b> &amp; <img src=\"file://$out/picture.png\"/> <a href=\"https://example.com\">link</a>"
wait_state toasts 4
settle
shot toast-pictures
reset
# Raw pixels, as most apps send a picture.
red="255,0,0,255, 255,0,0,255, 255,0,0,255, 255,0,0,255"
send -a Photos -h "variant:image-data:(2, 2, 8, true, 8, 4, [byte $red])" "With raw pixels" "From the image-data hint."
wait_state toasts 1
settle
shot toast-pixels
looks toast-pixels 1050 76 ff0000
reset

# What can be shown is, whatever its file is called. What can't is the bell,
# not Qt's placeholder, and nothing comes from a network.
step "Paths"
pictured() {
	send -a Mail "$@" "With a path" "Or so it says."
	wait_state toasts 1
	settle
	shot pictured
	got=$(area pictured "$tile")
	reset
}
pictured -i "$out/picture.png"
pic=$got
[ "$pic" != "$bell" ]
cp "$out/picture.png" "$out/pic 100%.png"
cp "$out/picture.png" "$out/what?#.png"
for icon in "$out/pic 100%.png" "$out/what?#.png" "file://$out/pic%20100%25.png"; do
	pictured -i "$icon"
	[ "$got" = "$pic" ] || {
		echo "notifications: no picture from $icon" >&2
		exit 1
	}
done
pictured -h "string:image-path:$out/pic 100%.png"
[ "$got" = "$pic" ]
for icon in /no/such/file.png /no/such/file.svg /etc/hostname file:///no/such.png; do
	pictured -i "$icon"
	[ "$got" = "$bell" ] || {
		echo "notifications: no bell for $icon" >&2
		exit 1
	}
done
pictured -h "string:image-path:http://127.0.0.1:9/picture.png"
[ "$got" = "$bell" ]
# A pipe nobody writes to holds nothing up.
rm -f "$out/pipe.png"
mkfifo "$out/pipe.png"
pictured -i "$out/pipe.png"
[ "$got" = "$bell" ]

# Long text is cut, not spilled.
step "Long text"
send -a "An application with a name that goes on and on and on and on and on and on" \
	"A summary that goes on for much longer than one line of a toast could ever hold, so that it has to be cut somewhere" \
	"Line one
line two
line three
line four
line five
line six
line seven
AnUnbrokenWordThatHasNoSpacesAtAllAndGoesOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOn" \
	-A one="An action with a really long label that would not fit in a toast" -A two=Two >/dev/null &
sender=$!
wait_state toasts 1
settle
shot toast-long
stop_sender
reset
# A name with lines in it is still one line.
send -a "$(printf 'One\nTwo\nThree')" "Summary" "Body"
wait_state toasts 1
settle
shot toast-name-lines
looks toast-name-lines "$toast_x" 140 "$backdrop"
reset

# No app name: no icon of some other app.
step "No app name"
send -a "" "Nameless" "From nobody."
wait_state toasts 1
settle
shot nameless
[ "$(area nameless "$tile")" = "$bell" ]
reset

# Several at once: capped, newest on top, a critical one too.
step "Several at once"
for n in 1 2 3 4 5; do
	send -a Chat "Message $n" "Number $n of a few."
done
send -a Chat -u critical "Message 6" "The newest one, and critical."
wait_state history 6
wait_state toasts 4
settle
shot toast-several
looks toast-several "$toast_x" 42 ee6666
is unread 6
reset

# A critical one isn't pushed out by those after it.
step "A critical one, pushed"
send -a Battery -u critical "Battery low" "Stays."
for n in 1 2 3 4 5; do
	send -a Chat "Message $n" "Number $n."
done
wait_state history 6
wait_state toasts 4
settle
shot toast-critical-kept
reset

# A replaced one changes in place, and comes back when its toast had gone.
step "A replaced one"
id=$(send -p -a Sync -t 1000 "Syncing" "1 of 3")
wait_state toasts 1
sleep 0.7
send -a Sync -t 1000 -r "$id" "Syncing" "2 of 3"
sleep 0.7
is toasts 1
is history 1
wait_state toasts 0 20
send -a Sync -t 1000 -r "$id" "Syncing" "3 of 3"
wait_state toasts 1
is history 1
reset
# The same words and only a new urgency.
id=$(send -p -a Sync -t 500 "Syncing" "Stuck")
wait_state toasts 1
wait_state toasts 0 20
send -a Sync -u critical -t 500 -r "$id" "Syncing" "Stuck"
wait_state toasts 1
reset
# The same words and nothing else, from a new process: back up, and on a new
# timer if it was still up.
id=$(send -p -a Sync -t 1000 "Syncing" "Again")
wait_state toasts 1
wait_state toasts 0 20
send -a Sync -t 1000 -r "$id" "Syncing" "Again"
wait_state toasts 1
sleep 0.7
send -a Sync -t 1000 -r "$id" "Syncing" "Again"
sleep 0.7
is toasts 1
wait_state toasts 0 20
reset

# A transient one is a toast and nothing else.
step "A transient one"
send -w -a Volume -e -t 800 "Transient" "Not for the history." &
sender=$!
wait_state toasts 1
is history 0
is unread 0
wait_state toasts 0 20
# Closed, too: notify-send -w saw it go.
wait "$sender"
reset

# The panel: unread goes to zero, and toasts stay out of its way.
step "The panel"
send -a Mail "First" "The oldest of them."
wait_state history 1
send -a Mail -A open=Open "Second" "With an action." >/dev/null &
sender=$!
wait_state history 2
send -a Mail -u critical "Third" "Critical, and the newest."
wait_state toasts 3
is unread 3
ipc notifications toggle
wait_state panel true
wait_state toasts 0
is unread 0
settle
shot panel
looks panel 700 500 "$backdrop"
# Live: what comes in shows here and makes no toast.
send -a Mail "Fourth" "While the panel is open."
wait_state history 4
is toasts 0
settle
shot panel-live
# Escape, then a click elsewhere.
key Escape
wait_state panel false
wait_state toasts 1
is unread 0
ipc notifications toggle
wait_state panel true
settle
move 300 600
click
wait_state panel false
ipc notifications toggle
wait_state panel true
settle
# Folded under its heading, the newest shows. Opened, the close button of the top
# one, and only that one goes.
is shown 1
move 1200 106
click
wait_state shown 4
settle
move 1363 143
click
wait_state history 3
settle
shot panel-closed-one
# Clear all.
move 1331 67
click
wait_state history 0
stop_sender
settle
shot panel-empty
looks panel-empty "$toast_x" 90 000000

step "Critical, the panel open"
send -a Battery -u critical "Later" "Waits for the panel to close."
wait_state history 1
is toasts 0
key Escape
wait_state panel false
wait_state toasts 1
reset
ipc notifications toggle
wait_state panel true
settle

step "Do Not Disturb"
move 1360 "$empty_toggle_y"
click
wait_state dnd true
settle
shot panel-dnd
# Its knob went right: there it's the panel's color, off it was the track's.
looks panel-dnd 1369 "$empty_toggle_y" 000000
key Escape
wait_state panel false
settle
send -a Mail "Quiet" "No toast for this one."
wait_state history 1
is toasts 0
is unread 1
settle
shot dnd-quiet
looks dnd-quiet "$toast_x" 90 "$backdrop"
# A transient one that can't show is gone at once.
send -a Volume -e "Transient" "Nowhere to be."
sleep 0.3
is history 1
is toasts 0
send -a Battery -u critical "Loud" "Through Do Not Disturb."
wait_state toasts 1
wait_state history 2
ipc notifications dnd false
wait_state dnd false
reset
# Turned on with toasts up, it takes down all but the critical ones.
send -a Mail "Normal" "Goes at once."
wait_state history 1
send -a Battery -u critical "Critical" "Stays."
wait_state toasts 2
ipc notifications dnd true
wait_state dnd true
wait_state toasts 1
is history 2
ipc notifications dnd false
wait_state dnd false
reset
# Replaced by a critical one, it comes through after all.
ipc notifications dnd true
wait_state dnd true
id=$(send -p -a Sync "Syncing" "Quietly.")
wait_state history 1
is toasts 0
send -a Sync -u critical -r "$id" "Failed" "Not so quietly."
wait_state toasts 1
is history 1
ipc notifications dnd false
wait_state dnd false
reset

step "Keys"
send -a Mail "One" "Tab goes through the panel."
wait_state toasts 1
ipc notifications toggle
wait_state panel true
settle
key Tab
settle
shot panel-focus
key Tab
key Tab
key space
wait_state dnd true
key space
wait_state dnd false
key Escape
wait_state panel false
reset
# The default action has no button: the card is what Tab gets to.
send -a Chat -A default=Reply "Someone wrote" "Enter is the click." >/dev/null &
sender=$!
wait_state toasts 1
ipc notifications toggle
wait_state panel true
settle
key Tab
key Tab
settle
shot panel-card-focus
looks panel-card-focus "$toast_x" 92 ffffff
actions=$(log | grep -c 'notification action default')
key Return
wait_state panel false
[ "$(log | grep -c 'notification action default')" = "$((actions + 1))" ]
stop_sender
reset

step "A long history"
for n in $(seq 1 12); do
	send -a Chat "Message $n" "A notification with a second line, for the list to have some height to it."
done
wait_state history 12
ipc notifications toggle
wait_state panel true
settle
# One app's fold up under its heading: a click opens them.
is shown 1
move 1200 106
click
wait_state shown 12
move 300 600
settle
shot panel-long
# The stand's wheel comes in a burst that Flickable drops, so by the keys.
key Down
key Down
sleep 1
shot panel-scrolled
[ "$(area panel-long 356x700+1028+92)" != "$(area panel-scrolled 356x700+1028+92)" ]
key Up
key Up
key Up
# Back at the top, once the flick has ended.
list_area=356x700+1028+92
for _ in $(seq 8); do
	shot panel-back
	[ "$(area panel-long "$list_area")" = "$(area panel-back "$list_area")" ] && break
	sleep 0.5
done
[ "$(area panel-long "$list_area")" = "$(area panel-back "$list_area")" ]
# Tab goes in the order they show in, not the one they were made in: the one
# that came in last is the first, after all that scrolling too.
send -a Chat -t 1 "Message 13" "Comes in last and shows on top."
wait_state history 13
key Tab
key Tab
key space
wait_state history 12
settle
shot panel-newest-closed
# The cards, all but the ring on the next one.
alike panel-long panel-newest-closed 300x670+1028+122
# The keys went on to the next one, and the list goes where they go, past what
# showed: Message 4 of what's left.
for _ in $(seq 8); do
	key Tab
done
settle
shot panel-tabbed
[ "$(area panel-long "$list_area")" != "$(area panel-tabbed "$list_area")" ]
key space
wait_state history 11
settle
shot panel-tab-closed
[ "$(area panel-tabbed "$list_area")" != "$(area panel-tab-closed "$list_area")" ]
# Past 3, 2 and 1 to the switch, then back up to 2.
key Tab
key Tab
key Tab
key ISO_Left_Tab
key ISO_Left_Tab
settle
shot panel-backtabbed
key space
wait_state history 10
# With the last one gone it's the switch again.
key space
wait_state history 9
settle
shot panel-last-closed
key space
wait_state dnd true
key space
wait_state dnd false
key Escape
wait_state panel false
reset
# Left scrolled and emptied: a new theme doesn't lay it out in a loop.
printf '{"radius":0}\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5

# The oldest make room, and their apps hear of it. A critical toast stays
# while it's up, however old.
step "A full history"
# Without a timeout and without a toast: it only returns when it was closed.
ipc notifications dnd true
wait_state dnd true
send -w -a Chat "The oldest" "Goes first." >/dev/null &
sender=$!
wait_state history 1
ipc notifications dnd false
wait_state dnd false
send -a Battery -u critical "Battery low" "Older than most."
wait_state history 2
for n in $(seq 100); do
	send -a Chat -t 1 "Message $n" "One of many."
done
wait_state history 101
wait "$sender"
wait_state toasts 1
settle
shot history-full
move "$top_close_x" "$top_close_y"
click right
wait_state history 100
wait_state toasts 0
move 300 600
ipc notifications toggle
wait_state panel true
settle
shot history-full-panel
# On the newest, wherever it was left.
looks history-full-panel 1046 92 "$(pixel panel-long 1046 92)"
key Escape
wait_state panel false
send -a Chat -t 1 "One more" "Still a hundred."
sleep 0.3
is history 100
reset

step "Recalled"
id=$(send -p -a Sync -t 0 "Recalled" "Its app takes it back.")
wait_state toasts 1
dbus-send --session --type=method_call --dest=org.freedesktop.Notifications /org/freedesktop/Notifications \
	org.freedesktop.Notifications.CloseNotification "uint32:$id"
wait_state toasts 0
wait_state history 0
caps=$(dbus-send --session --print-reply --dest=org.freedesktop.Notifications /org/freedesktop/Notifications \
	org.freedesktop.Notifications.GetCapabilities)
for cap in actions persistence body icon-static; do
	echo "$caps" | grep -q "\"$cap\""
done
if echo "$caps" | grep -q "body-"; then
	echo "notifications: says it does more than plain text: $caps" >&2
	exit 1
fi
reset

step "Light"
printf '{"extends":"light"}\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5
send -a Mail "Hello there" "A normal notification, in the light theme."
send -a Files -A open=Open -A folder="Show in folder" "Download finished" "report.pdf" >/dev/null &
sender=$!
wait_state history 2
send -a Photos -i "$out/picture.png" "With a picture" "From the app."
send -a Battery -u critical "Battery low" "Plug it in."
wait_state toasts 4
settle
shot light-toasts
looks light-toasts "$toast_x" 90 ffffff
ipc notifications toggle
wait_state panel true
settle
shot light-panel
looks light-panel 1026 60 ffffff
key Escape
wait_state panel false
stop_sender
reset
ipc notifications toggle
wait_state panel true
settle
shot light-panel-empty
key Escape
wait_state panel false

step "Square, no animations"
printf '{"radius":0,"animations":false}\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5
send -a Photos -i "$out/picture.png" "Square" "Corners from the theme."
send -a Files -A open=Open "No animations" "Still comes and goes." >/dev/null &
sender=$!
wait_state toasts 2
shot square-toasts
[ "$(pixel square-toasts 1016 42)" != "$backdrop" ]
ipc notifications toggle
wait_state panel true
shot square-panel
settle
key Escape
wait_state panel false
stop_sender
reset
niri msg --json layers | jq -e '[.[] | select(.namespace == "okaeri-toasts")] | length == 0' >/dev/null
# The keys scroll at once, and it stays there.
for n in $(seq 1 12); do
	send -a Chat -t 1 "Message $n" "A notification with a second line, for the list to have some height to it."
done
wait_state history 12
ipc notifications toggle
wait_state panel true
shot square-long
key Down
shot square-scrolled
sleep 0.3
shot square-still
[ "$(area square-long "$list_area")" != "$(area square-scrolled "$list_area")" ]
[ "$(area square-scrolled "$list_area")" = "$(area square-still "$list_area")" ]
key Escape
wait_state panel false
reset
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.5

step "Clicks on a toast"
# The left one goes to its app, the right one is the close button's.
send -a Editor "To its app" "No default action."
wait_state toasts 1
settle
move "$toast_x" 90
click
wait_log "okaeri: dry: notification focus Editor"
wait_state toasts 0
send -a Mail -A default=Open "Its action" "The right click doesn't take it." >/dev/null &
sender=$!
wait_state toasts 1
settle
move "$toast_x" 90
click right
wait_state toasts 0
! log | grep -q "notification action default.*Mail" || fail "a right click took the action"
stop_sender
reset

step "A screenshot"
# niri's own word of it: the picture whole, and the left click opens the file.
niri msg action screenshot-screen
wait_state toasts 1
settle
shot screenshot
[ "$(magick "$out/screenshot.png" -crop 340x180+1030+125 +repage -format '%k' info:)" -gt 10 ] || fail "no picture on the toast"
saved=$(ls "$work"/shots/*.png)
move "$toast_x" 200
click
wait_log "okaeri: dry: notification open $saved"
wait_state toasts 0
sleep 1.1
niri msg action screenshot-screen
wait_state toasts 1
settle
move "$toast_x" 200
click right
wait_state toasts 0
[ "$(log | grep -c "okaeri: dry: notification open")" = 1 ] || fail "a right click opened the screenshot"
is history 0
reset

step "Do Not Disturb for a while"
ipc notifications toggle
wait_state panel true
settle
move 1100 "$empty_toggle_y"
wheel 1
wait_state dnd true
settle
shot dnd-wheel
wheel -1
wait_state dnd false
key Escape
wait_state panel false
ipc notifications dndFor 2
wait_state dnd true
sleep 3.2
is dnd false

step "Rules"
printf '{ "notifications": { "rules": [ { "app": "quiet", "toast": false }, { "app": "Passing", "history": false }, { "app": "muted", "toast": false, "history": false } ] } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.4
# No toast, in the history all the same.
send -a Quiet "No toast" "Only in the history."
wait_state history 1
sleep 0.4
is toasts 0
# A toast, and gone when it's gone.
send -a Passing -t 500 "No history" "Only a toast."
wait_state toasts 1
is history 1
wait_state toasts 0
is history 1
# Neither.
send -a Muted "Nothing" "Not at all."
sleep 0.4
is toasts 0
is history 1
# A critical one comes through all the same.
send -a Muted -u critical "Urgent" "It shows."
wait_state toasts 1
reset
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.4

step "By app"
send -a Mail -t 1 "One" "A letter."
send -a Chat -t 1 "Two" "A message."
send -a Mail -t 1 "Three" "Another letter."
wait_state history 3
notifications_order() {
	ipc notifications state | jq -c .order
}
[ "$(notifications_order)" = '["Mail","Mail","Chat"]' ] || fail "not by app: $(notifications_order)"
wait_state toasts 0
ipc notifications toggle
wait_state panel true
settle
shot by-app
# Folded to the newest of each, and a click on the heading shows the rest.
is shown 2
move 1200 106
click
wait_state shown 3
settle
shot by-app-open
click
wait_state shown 2
# Opened again, it starts folded.
click
wait_state shown 3
key Escape
wait_state panel false
ipc notifications toggle
wait_state panel true
settle
is shown 2
# The first group's close button: all of it goes.
move 1370 106
click
wait_state history 1
[ "$(notifications_order)" = '["Chat"]' ] || fail "the wrong app went: $(notifications_order)"
key Escape
wait_state panel false
reset

step "Clicks go through"
if command -v kitty >/dev/null; then
	# Two windows in the inner niri, the right one under the toasts. With no
	# bus: on one it would start portals and a keyring.
	DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 sleep 40 &
	left_pid=$!
	sleep 1.5
	DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --config NONE -o confirm_os_window_close=0 sleep 40 &
	right_pid=$!
	sleep 1.5
	focused() {
		niri msg --json focused-window | jq -r .id
	}
	right=$(focused)
	niri msg action focus-column-left
	sleep 0.3
	left=$(focused)
	[ "$left" != "$right" ]
	send -a Clock -t 0 "Upper" "Stays till closed."
	wait_state history 1
	send -a Clock -t 0 "Lower" "Stays till closed."
	wait_state toasts 2
	settle
	shot through
	# It took no keyboard.
	[ "$(focused)" = "$left" ]
	# On a toast the click stays there; between two and under them it doesn't.
	move "$toast_x" 90
	click
	[ "$(focused)" = "$left" ]
	move "$toast_x" 128
	click
	[ "$(focused)" = "$right" ]
	niri msg action focus-column-left
	sleep 0.3
	[ "$(focused)" = "$left" ]
	move "$toast_x" 500
	click
	[ "$(focused)" = "$right" ]
	kill "$left_pid" "$right_pid" 2>/dev/null || true
	wait "$left_pid" "$right_pid" 2>/dev/null || true
	reset
else
	echo "notifications: no kitty here, not tried" >&2
fi

step "The bell"
# The reload is a test of its own: what was there stays, and only a critical
# toast comes back.
send -a Mail "Before the reload" "Stays in the history."
send -a Mail "Another one" "This one too."
wait_state history 2
wait_state toasts 2
wait_state toasts 0 80
send -a Battery -u critical "Still here" "Critical: up again after the reload."
wait_state toasts 1
# A reload reads the file, and what changed reaches that a moment later.
sleep 0.8
printf '\n// Once more.\n' >>"$work/shell/bar/Bar.qml"
wait_log 'Reloading configuration'
wait_state history 3
wait_state toasts 1
settle
shot bell-unread
# Left of everything else on the bar. It gets wider with a number, to the left.
bell=$(lane bell-unread | head -n 1)
strip=120x34+$((bell - 90))+0
# A click opens the panel, which makes them read.
move "$bell" 16
click
wait_state panel true
is unread 0
settle
shot bell-open
click
wait_state panel false
move 300 600
settle
shot bell-read
[ "$(area bell-unread $strip)" != "$(area bell-read $strip)" ]
ipc notifications dnd true
wait_state dnd true
settle
shot bell-dnd
ipc notifications dnd false
wait_state dnd false
[ "$(area bell-read $strip)" != "$(area bell-dnd $strip)" ]
reset

# Over the next reload: what's been read, Do Not Disturb, and one that's
# replaced after it.
send -a Mail "Read already" "Looked at before the reload."
wait_state history 1
ipc notifications toggle
wait_state panel true
key Escape
wait_state panel false
is unread 0
id=$(send -p -a Sync "Syncing" "1 of 2")
wait_state history 2
is unread 1
ipc notifications toggle
wait_state panel true
key Escape
wait_state panel false
ipc notifications dnd true
wait_state dnd true

step "A real action"
# Env.act only logs here. On the stand's copy, these pass: they reach nothing
# but notify-send, on the stand's private bus.
sed 's/^\t\tif (dry)$/\t\tif (dry \&\& !what.startsWith("notification action"))/' "$work/shell/services/Env.qml" >"$work/Env.qml"
grep -q 'what.startsWith' "$work/Env.qml"
sleep 0.8
cat "$work/Env.qml" >"$work/shell/services/Env.qml"
for _ in $(seq 50); do
	[ "$(log | grep -c 'Reloading configuration')" -ge 2 ] && break
	sleep 0.1
done
sleep 0.5
wait_state history 2
is dnd true
is unread 0
ipc notifications dnd false
wait_state dnd false
send -a Sync -r "$id" "Syncing" "2 of 2"
wait_state toasts 1
reset
# From a toast: the app gets it, and the notification is done. Twice: the
# second click finds it on its way out.
send -a Files -A open=Open "Download finished" "report.pdf" >"$out/action" &
sender=$!
wait_state toasts 1
settle
move 1109 133
wlrctl pointer click left
wlrctl pointer click left
wait "$sender"
[ "$(cat "$out/action")" = open ]
wait_state history 0
wait_state toasts 0
# From the panel: the same, and the panel gets out of the way.
move 300 600
send -a Files -A open=Open "Download finished" "report.pdf" >"$out/action" &
sender=$!
wait_state toasts 1
ipc notifications toggle
wait_state panel true
settle
shot action-panel
move 1126 183
click
wait "$sender"
[ "$(cat "$out/action")" = open ]
wait_state panel false
wait_state history 0

step "Two calls at once"
# The second closes what never got to show: nothing stays up with the keys.
ipc notifications toggle &
first=$!
ipc notifications toggle
wait "$first"
wait_state panel false
settle
niri msg --json layers | jq -e '[.[] | select(.namespace == "okaeri-panel")] | length == 0' >/dev/null


step "The battery"
# On a stand-in told by calls: part.sh made its numbers plain ones.
sed -e 's/^import qs$/import qs\nimport Quickshell.Io/' -e '$d' "$work/shell/services/Power.qml" >"$work/Power.qml"
cat >>"$work/Power.qml" <<'QML'

	IpcHandler {
		target: "battery"

		function set(charge: int, draining: bool): void {
			power.charge = charge;
			power.draining = draining;
		}
	}
}
QML
mv "$work/Power.qml" "$work/shell/services/Power.qml"
printf '\n' >>"$work/shell/shell.qml"
sleep 3.5
ipc notifications clear
wait_state history 0
ipc battery set 50 true
ipc battery set 21 true
settle
is history 0
# Down to the line: one, and only one, however it goes up and down from there.
ipc battery set 20 true
wait_state toasts 1
is history 1
shot battery-low
ipc battery set 19 true
ipc battery set 21 true
ipc battery set 20 true
settle
is history 1
# The last call takes its place and stays.
ipc battery set 5 true
settle
is history 1
is toasts 1
shot battery-empty
sleep 7
is toasts 1
# The charger takes it back, and it can be said again.
ipc battery set 5 false
wait_state history 0
wait_state toasts 0
ipc battery set 3 true
wait_state toasts 1
is history 1
ipc battery set 100 false
wait_state history 0
# A start on a low battery says it, and with the warning off nothing does.
printf '{ "battery": { "warning": 0 } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.5
ipc battery set 3 true
settle
is history 0
ipc battery set 100 false
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"

step "Sounds"
sounds() {
	log | grep -c "okaeri: dry: sound $1" || true
}
# Sounds close together make one: the last one here was the charger.
sleep 0.3
before=$(sounds message-new-instant)
warned=$(sounds dialog-warning)
send -a Chat "A word"
wait_state toasts 1
settle
same_count() {
	[ "$(sounds "$1")" = "$2" ] || {
		echo "notifications: $(sounds "$1") of sound $1, not $2" >&2
		return 1
	}
}
same_count message-new-instant $((before + 1))
sleep 0.2
ipc notifications dnd true
send -a Chat "Quiet"
settle
same_count message-new-instant $((before + 1))
ipc notifications dnd false
sleep 0.2
send -u low -a Chat "Low"
settle
same_count message-new-instant $((before + 1))
sleep 0.2
send -u critical -a Chat "Loud"
settle
same_count dialog-warning $((warned + 1))
ipc notifications clear
wait_state history 0
# The charger, both ways, and nothing for a warning's level going up.
plug=$(sounds power-plug)
unplug=$(sounds power-unplug)
ipc battery set 80 true
settle
same_count power-unplug $((unplug + 1))
ipc battery set 80 false
settle
same_count power-plug $((plug + 1))
# Off is off.
printf '{ "sounds": { "volume": 0 } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.5
send -a Chat "Silent"
settle
same_count message-new-instant $((before + 1))
printf '{ "sounds": { "notifications": false } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.5
send -a Chat "Silent too"
settle
same_count message-new-instant $((before + 1))
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
ipc notifications clear
wait_state history 0

step "Over a restart"
restart() {
	kill "$qs_pid"
	wait "$qs_pid" 2>/dev/null || true
	quickshell -p "$work/shell" >>"$out/qs.log" 2>&1 &
	qs_pid=$!
	sleep 3
}
kept=$XDG_STATE_HOME/okaeri/notifications/history.json
send -a Mail "Older" "from the first app"
send -a Chat "Newer" "from the second"
send -a Passing --transient "Gone by"
wait_state history 2
sleep 1
[ "$(stat -c %a "$(dirname "$kept")")" = 700 ] || {
	echo "notifications: anyone can read the history" >&2
	return 1
}
[ "$(jq length "$kept")" = 2 ] || {
	echo "notifications: the file has $(jq -c . "$kept")" >&2
	return 1
}
restart
wait_state history 2
is toasts 0
is unread 2
[ "$(state 'order | join(" ")')" = "Chat Mail" ] || {
	echo "notifications: in the order $(state order)" >&2
	return 1
}
ipc notifications toggle
wait_state panel true
settle
shot past-panel
ipc notifications toggle
wait_state panel false
is unread 0
sleep 1
restart
wait_state history 2
is unread 0
# New ones go over them, a reload doesn't make two of what's still there.
send -a Chat "Newest"
wait_state history 3
sleep 1
printf '\n' >>"$work/shell/shell.qml"
sleep 2.5
wait_state history 3
# Clearing goes for them too, and it stays cleared.
ipc notifications clear
wait_state history 0
sleep 1
[ "$(jq length "$kept")" = 0 ] || {
	echo "notifications: cleared, the file has $(jq -c . "$kept")" >&2
	return 1
}
restart
wait_state history 0
# Turned off, nothing's kept, and what was there goes.
send -a Chat "Kept for a moment"
wait_state history 1
sleep 1
printf '{ "notifications": { "keep": false } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 1.5
[ "$(jq length "$kept")" = 0 ] || {
	echo "notifications: off, the file has $(jq -c . "$kept")" >&2
	return 1
}
restart
wait_state history 0
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"

step "The same again"
config=$XDG_CONFIG_HOME/okaeri/settings.json
ipc notifications clear
wait_state history 0
send -a Kitty "Waiting" "For your input."
wait_state history 1
send -a Kitty "Waiting" "For your input."
send -a Kitty "Waiting" "For your input."
sleep 0.5
is history 1
is toasts 1
[ "$(state 'repeats[0]')" = 3 ] || {
	echo "notifications: it stands for $(state repeats)" >&2
	return 1
}
[ "$(state 'when[0]')" = now ] || {
	echo "notifications: it came $(state when)" >&2
	return 1
}
# Another text isn't the same, and folds under the app.
send -a Kitty "Waiting" "For something else."
wait_state history 2
is shown 1
# Kept over a restart, with when it came.
sleep 1
restart
wait_state history 2
[ "$(state 'repeats | join(" ")')" = "1 3" ] || {
	echo "notifications: after a restart $(state repeats)" >&2
	return 1
}
[ "$(state 'when[1]')" = now ] || {
	echo "notifications: after a restart it came $(state when)" >&2
	return 1
}
ipc notifications clear
wait_state history 0
printf '{ "notifications": { "stack": false } }\n' >"$config"
sleep 0.5
send -a Kitty "Waiting" "Twice."
send -a Kitty "Waiting" "Twice."
wait_state history 2
printf '{}\n' >"$config"
sleep 0.5
ipc notifications clear
wait_state history 0
# Too old goes at a start.
sleep 1
printf '[{ "id": 7, "appName": "Old", "desktopEntry": "", "summary": "Old", "body": "", "image": "", "appIcon": "", "urgency": 1, "unread": false, "time": 1000, "repeats": 1 }]' >"$kept"
printf '{ "notifications": { "maxAge": 7 } }\n' >"$config"
sleep 0.5
restart
wait_state history 0
printf '{}\n' >"$config"
sleep 0.5

step "What's on a card"
long=$(printf 'A long line of text that goes on and on, and wraps over the width of the card. %.0s' 1 2 3 4 5 6)
send -a Mail -h int:value:40 "Long" "$long"
wait_state history 1
wait_state toasts 1
move 300 600
ipc notifications toggle
wait_state panel true
settle
shot card-folded
# How far along: the bar's filled part is the accent's.
looks card-folded 1100 258 ffffff
move 1117 238
click
settle
shot card-open
[ "$(area card-folded 356x300+1028+92)" != "$(area card-open 356x300+1028+92)" ]
log_copies=$(log | grep -c 'dry: notification copy' || true)
move 1337 112
click
sleep 0.3
[ "$(log | grep -c 'dry: notification copy')" = "$((log_copies + 1))" ] || {
	echo "notifications: nothing copied" >&2
	return 1
}
key Escape
wait_state panel false
ipc notifications clear
wait_state history 0
# An answer goes to the app, by the field the card has for it.
timeout 20 notify-send -a Chat -A inline-reply=Reply "Friend" "Can you answer?" >/dev/null &
sender=$!
wait_state history 1
wait_state toasts 1
ipc notifications toggle
wait_state panel true
settle
move 1230 177
click
type 'on my way'
key Return
wait_log 'dry: notification reply'
log | grep -q 'on my way' && {
	echo "notifications: what was typed is in the log" >&2
	return 1
}
key Escape
wait_state panel false
stop_sender
ipc notifications clear
wait_state history 0
