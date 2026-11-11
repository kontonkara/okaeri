# The settings window with the real pointer: what it changes goes to the shell's
# own file, over a config that can't be written, and the bar follows.

fail() {
	echo "settings: $1" >&2
	exit 1
}
step() {
	echo "settings: $1" >&2
}
same() {
	[ "$2" = "$3" ] || fail "$1: got \"$2\", not \"$3\""
}

own=$XDG_STATE_HOME/okaeri/settings.json
config=$XDG_CONFIG_HOME/okaeri/settings.json
# 1400x900: the search, the pages under it, the drawer's switch, the rows of the
# lanes and the pictures.
menu_x=420
search_y=216
bar_y=257
tray_y=295
control_y=333
launcher_y=371
clipboard_y=409
notifications_y=447
sounds_y=485
osd_y=523
display_y=561
wallpaper_y=599
look_y=637
session_y=675
back_y=722
switch_x=1034
drawer_y=233
left_y=251
middle_y=374
right_y=497
right2_y=533
off_y=620
off_gap_y=660
# The part made here: in the last lane, on its third line, and on the left once
# it's there.
script_x=882
script_y=691
script_on_x=796
field_y=257
picture_y=339
lower_x=948
higher_x=1040
lock_y=255
screens_y=295
wait_y=485
sleep_y=379
logout_y=669

value() {
	jq -c "$1" "$own"
}
up() {
	niri msg --json windows | jq '[.[] | select(.title == "Settings")] | length'
}
wait_up() {
	for _ in $(seq 30); do
		[ "$(up)" = "$1" ] && return 0
		sleep 0.1
	done
	fail "$(up) windows up, not $1"
}
pixel() {
	magick "$out/$1.png" -format "%[hex:u.p{$2,$3}]" info: | cut -c1-6
}
# The right end of the switch at height $2 in shot $1: the knob, on one that's on.
knob() {
	magick "$out/$1.png" -format "%[pixel:p{$((switch_x + 9)),$2}]" info:
}
# To the page at height $1.
page() {
	move "$menu_x" "$1"
	click
	sleep 0.4
}
# Takes what's at $1 $2 to $3 $4.
drag() {
	move "$1" "$2"
	hold
	move "$3" "$4"
	let_go
	sleep 0.2
}
# What's typed in the field at $1 $2, kept with Enter.
field() {
	move "$1" "$2"
	click
	wtype -M ctrl a -m ctrl
	type "$3"
	key Return
	sleep 0.3
}
# The folder field, with $1 in it.
folder() {
	move 790 "$field_y"
	click
	wtype -M ctrl a -m ctrl
	type "$1"
	key Return
	sleep 0.5
}

# The window at the size these were written for, as if it was made that once.
mkdir -p "$XDG_STATE_HOME/okaeri"
printf '{"width":760,"height":564}\n' >"$XDG_STATE_HOME/okaeri/settings-window.json"

step "A config that can't be written"
printf '{ "tray": { "drawer": true } }\n' >"$config"
chmod 444 "$config"
sleep 0.4
ipc settings toggle
wait_up 1
sleep 0.4
[ ! -e "$own" ] || fail "a file before anything changed"
page "$tray_y"
shot open
on=$(knob open "$drawer_y")

step "Over the config"
move "$switch_x" "$drawer_y"
click
sleep 0.3
same "the drawer in the shell's file" "$(value .tray.drawer)" false
same "the config" "$(cat "$config")" '{ "tray": { "drawer": true } }'
shot drawer-off
[ "$(knob drawer-off "$drawer_y")" != "$on" ] || fail "the switch didn't follow"

step "A part held"
# The bar as it was laid out when these were written, whatever the defaults are now.
printf '{ "tray": { "drawer": true }, "bar": { "left": ["workspaces", "media"], "center": ["clock"], "right": ["cast", "units", "tray", "notifications", "clipboard", "battery", "control"] } }\n' >"$config.new"
chmod 644 "$config"
mv "$config.new" "$config"
sleep 0.5
page "$bar_y"
move 554 "$middle_y"
hold
move 700 "$left_y"
sleep 0.3
shot held
same "what's held, at the pointer" "$(pixel held 676 "$left_y")" FFFFFF
same "the bar while it's held" "$(value .bar)" null
let_go
sleep 0.3

step "To another lane"
same "the left" "$(value .bar.left)" '["workspaces","media","clock"]'
same "the middle" "$(value .bar.center)" '[]'
move 300 800
sleep 0.3
shot no-clock
[ "$(magick "$out/no-clock.png" -crop 200x20+600+10 +repage -format '%[fx:maxima]' info:)" = 0 ] || fail "the clock is still in the middle"
[ "$(magick "$out/no-clock.png" -crop 100x20+130+10 +repage -format '%[fx:maxima]' info:)" != 0 ] || fail "the clock isn't on the left"

step "Along a lane"
drag 559 "$right2_y" 762 "$right_y"
same "the right" "$(value .bar.right)" '["cast","units","battery","tray","notifications","clipboard","control"]'

step "Off the bar"
drag 795 "$right_y" 800 "$off_gap_y"
same "the right" "$(value .bar.right)" '["cast","units","tray","notifications","clipboard","control"]'

step "Back on it"
drag 768 "$off_y" 800 "$right2_y"
same "the right" "$(value .bar.right)" '["cast","units","tray","notifications","clipboard","control","keyboard"]'

step "What has to stay"
drag 584 "$right2_y" 800 "$off_gap_y"
same "the right" "$(value .bar.right)" '["cast","units","tray","notifications","clipboard","control","keyboard"]'

step "A click is no drag"
before=$(value .bar)
move 584 "$right2_y"
hold
let_go
same "the bar" "$(value .bar)" "$before"

step "A part's own settings"
# Up to the lanes: a part's card took the page down to it.
to_top() {
	move 700 400
	notch -30
	sleep 0.6
}
# The part at $1 $2: its card comes up at the foot of the page.
choose() {
	to_top
	move "$1" "$2"
	click
	sleep 0.8
}
choose 745 "$left_y"
shot part-clock
move "$switch_x" 520
click
sleep 0.3
same "seconds" "$(value .clock.seconds)" true
move "$higher_x" 374
click
sleep 0.3
same "the date" "$(value .clock.date)" '"after"'
move 968 424
click
wtype -M ctrl a -m ctrl
type 'yyyy'
key Return
sleep 0.3
same "how the date's written" "$(value .clock.dateFormat)" '"yyyy"'
move "$higher_x" 564
click
sleep 0.3
same "the first day of a week" "$(value .clock.weekStart)" '"monday"'
move "$switch_x" 609
click
sleep 0.3
same "week numbers" "$(value .clock.weekNumbers)" true
field 934 659 'UTC, Asia/Tokyo'
same "the other places" "$(value .clock.zones)" '["UTC","Asia/Tokyo"]'
move "$switch_x" 709
click
sleep 0.3
same "the weather" "$(value .weather.on)" true
click
sleep 0.3
choose 577 "$left_y"
shot part-workspaces
move "$switch_x" 655
click
sleep 0.3
same "the empty ones" "$(value .workspaces.empty)" false
choose 559 "$off_y"
shot part-battery
move "$higher_x" 655
click
sleep 0.3
same "when the battery shows" "$(value .battery.show)" '"battery"'
# With a player open, to leave out.
mpv --no-config --no-terminal --ao=null --vo=null --pause --script="$OKAERI_MPV_MPRIS" av://lavfi:sine >/dev/null 2>&1 &
player=$!
sleep 2
choose 660 "$left_y"
shot part-media
move "$higher_x" 504
click
sleep 0.3
same "when the media shows" "$(value .media.show)" '"playing"'
move "$higher_x" 544
click
sleep 0.3
same "what the media says" "$(value .media.label)" '"both"'
move "$higher_x" 589
click
sleep 0.3
same "how wide the media gets" "$(value .media.width)" 280
move "$switch_x" 640
click
sleep 0.3
same "sliding" "$(value .media.scroll)" false
move "$switch_x" 710
click
sleep 0.3
same "the players left out" "$(value .media.ignored)" '["mpv"]'
kill "$player"
wait "$player" 2>/dev/null || true
choose 645 "$off_y"
shot part-bluetooth
move "$higher_x" 669
click
sleep 0.3
same "when Bluetooth shows" "$(value .bluetooth.show)" '"on"'
move "$higher_x" 709
click
sleep 0.3
same "what's beside Bluetooth" "$(value .bluetooth.label)" '"name"'
choose 737 "$off_y"
shot part-network
move "$higher_x" 709
click
sleep 0.3
same "what's beside the network" "$(value .network.label)" '"name"'
# One with a page of its own: a way there.
choose 785 "$right_y"
shot part-tray
move 1021 708
click
sleep 0.5
move "$switch_x" "$drawer_y"
click
sleep 0.3
same "the drawer, from the tray's page" "$(value .tray.drawer)" true
# Off again, as a later step has it.
click
sleep 0.3
same "the drawer, off again" "$(value .tray.drawer)" false

step "A part of one's own"
# The button under the lanes makes one, off the bar, with its card up. Dragged
# onto the bar, it's chosen anew, for its card to come up at the foot of the page.
page "$bar_y"
to_top
# A wheel's notch down: the lanes take the page, with all there is to put on them.
move 700 400
notch 1
sleep 0.6
move 1007 649
click
sleep 0.8
shot script-added
same "the part made" "$(value .bar.scripts)" '[{"name":"script","command":"","every":10}]'
to_top
drag "$script_x" "$script_y" 900 "$left_y"
same "the left with it" "$(value .bar.left)" '["workspaces","media","clock","script"]'
shot script-on
choose "$script_on_x" "$left_y"
choose "$script_on_x" "$left_y"
shot script-card
field 934 574 'echo hello'
same "its command" "$(value '.bar.scripts[0].command')" '"echo hello"'
move "$higher_x" 625
click
sleep 0.3
same "how often it runs" "$(value '.bar.scripts[0].every')" 30
# By another name it's the same part where it was, but not by a name that's taken.
field 934 525 'mine'
same "its name" "$(value '.bar.scripts[0].name')" '"mine"'
same "the left with its new name" "$(value .bar.left)" '["workspaces","media","clock","mine"]'
field 934 525 'clock'
same "a name that's taken" "$(value '.bar.scripts[0].name')" '"mine"'
shot script-refused
# Under its card, what clicks and the wheel on it run: a command, until the field
# is emptied. The last two of the five are in sight.
move 700 400
notch 30
sleep 0.6
shot script-clicks
field 932 214 'echo up'
field 932 258 'echo down'
same "what clicks and the wheel on it run" "$(value .bar.actions)" '{"mine":{"up":"echo up","down":"echo down"}}'
move 932 258
click
wtype -M ctrl a -m ctrl
key BackSpace
key Return
sleep 0.3
same "with a command gone" "$(value .bar.actions)" '{"mine":{"up":"echo up"}}'
# Removed, it leaves nothing of itself.
choose "$script_on_x" "$left_y"
choose "$script_on_x" "$left_y"
move 575 710
click
sleep 0.4
same "the parts with it removed" "$(value .bar.scripts)" '[]'
same "the left without it" "$(value .bar.left)" '["workspaces","media","clock"]'
same "the clicks without it" "$(value .bar.actions)" '{}'

step "All of the bar, and its screens"
page "$bar_y"
move 700 400
notch 30
sleep 0.6
shot bar-all
move "$higher_x" 450
click
sleep 0.3
same "the wheel" "$(value .bar.wheel)" '"volume"'
move "$switch_x" 500
click
sleep 0.3
same "tips" "$(value .bar.tips)" false
# The window's top: with the space given up it sits higher.
window_top() {
	niri msg --json windows | jq '[.[] | select(.title == "Settings") | .layout.tile_pos_in_workspace_view[1]][0] | floor'
}
top_before=$(window_top)
# A bar that hides gives its space up too.
move "$switch_x" 550
click
sleep 0.5
same "a bar that hides" "$(value .bar.autoHide)" true
move "$switch_x" $((550 + $(window_top) - top_before))
click
sleep 0.5
same "a bar that stays" "$(value .bar.autoHide)" false
move "$switch_x" 600
click
sleep 0.5
same "space for windows" "$(value .bar.reserve)" false
# Back on, where the switch is now.
move "$switch_x" $((600 + $(window_top) - top_before))
click
sleep 0.5
same "space for windows, again" "$(value .bar.reserve)" true
# The only screen keeps its bar.
move "$switch_x" 705
click
sleep 0.3
same "screens without a bar" "$(value .bar.hideOn)" null

step "The pictures of a folder"
mkdir "$work/pictures"
magick -size 1600x900 xc:'#336699' "$work/pictures/a blue.png"
magick -size 1600x900 xc:'#996633' "$work/pictures/brown #1?.png"
magick -size 1600x900 xc:'#339966' "$work/pictures/green.PNG"
printf 'not a picture\n' >"$work/pictures/notes.md"
page "$wallpaper_y"
folder "$work/pictures"
same "the folder" "$(value .wallpaper.folder)" "\"$work/pictures\""
sleep 0.5
shot pictures
same "the first" "$(pixel pictures 606 "$picture_y")" 336699
same "the second" "$(pixel pictures 790 "$picture_y")" 996633
same "the third" "$(pixel pictures 974 "$picture_y")" 339966
same "after those" "$(pixel pictures 606 443)" 000000

step "One to pick"
move 790 "$picture_y"
click
sleep 0.3
same "the wallpaper" "$(value .wallpaper.path)" "\"$work/pictures/brown #1?.png\""
move 300 800
sleep 0.3
shot picked
same "its ring" "$(pixel picked 703 "$picture_y")" FFFFFF
same "another's edge" "$(pixel picked 887 "$picture_y")" 339966

step "A folder that isn't there"
folder "~/no such folder"
same "the folder" "$(value .wallpaper.folder)" "\"$HOME/no such folder\""
move 300 800
sleep 0.3
shot nothing
same "where a picture was" "$(pixel nothing 606 "$picture_y")" 000000
[ "$(magick "$out/nothing.png" -crop 200x30+690+498 +repage -format '%[fx:maxima]' info:)" != 0 ] || fail "nothing says there's nothing"

step "How the wallpaper shows"
# The other leaf: how one fills the screen, how a new one comes, and when.
arrow() {
	move "$1" "$2"
	click
}
move 668 214
click
sleep 0.4
shot wallpaper-how
arrow "$higher_x" 300
same "how it fills" "$(value .wallpaper.fill)" '"fit"'
arrow "$higher_x" 439
same "how a new one comes" "$(value .wallpaper.transition)" '"slide"'
arrow "$higher_x" 524
same "another by itself" "$(value .wallpaper.every)" 5
move "$switch_x" 574
click
sleep 0.3
same "any of them" "$(value .wallpaper.random)" true
# Not while this goes on: back by the arrow of a line with words, further in.
arrow 912 524
same "another by itself, no more" "$(value .wallpaper.every)" 0

step "When things happen by themselves"
# The arrow at $1 on the line at $2.
arrow() {
	move "$1" "$2"
	click
}
page "$session_y"
arrow "$higher_x" "$lock_y"
same "the lock, one up" "$(value .idle.lock)" 900
arrow "$lower_x" "$lock_y"
arrow "$lower_x" "$lock_y"
same "the lock, two down" "$(value .idle.lock)" 300
# Eleven minutes isn't one of them: the next up is the next that is.
arrow "$higher_x" "$screens_y"
same "the screens, from what's not on the list" "$(value .idle.screenOff)" 900
arrow "$lower_x" "$wait_y"
same "the session menu's wait" "$(value .session.countdown)" 5
move "$switch_x" "$logout_y"
click
sleep 0.3
same "what the session menu leaves out" "$(value .session.hidden)" '["logout"]'
arrow "$higher_x" "$sleep_y"
same "sleep" "$(value .idle.suspend)" 60
# When, only with sleep on.
sleep 0.3
arrow "$higher_x" $((sleep_y + 50))
same "when it sleeps" "$(value .idle.suspendOn)" '"battery"'
# And not while something plays, unless that's turned off.
move "$switch_x" $((sleep_y + 95))
click
sleep 0.3
same "sleep with something playing" "$(value .idle.playingHolds)" false
shot session

step "The battery's line"
# At the foot of the page.
move 700 446
notch 30
sleep 0.6
battery_y=575
arrow "$lower_x" "$battery_y"
same "the warning" "$(value .battery.warning)" 15
arrow "$higher_x" "$battery_y"
arrow "$higher_x" "$battery_y"
same "the warning, two up" "$(value .battery.warning)" 25
move "$switch_x" 625
click
sleep 0.3
same "saving power from then on" "$(value .battery.saver)" true
arrow "$higher_x" 670
same "the lock on battery" "$(value .idle.batteryLock)" 60
# Over the battery's card, the commands for when things happen: the last of them.
field 934 473 'true'
same "what a new wallpaper runs" "$(value .hooks.wallpaper)" '"true"'

step "The control center's page"
page "$control_y"
shot control-page
# Wi-Fi, the first tile, to Hidden; the rest move up a place.
drag 656 254 600 480
same "what's left out" "$(value .control.hidden)" '["wifi"]'
same "the order" "$(value .control.tiles)" '["bluetooth","night","awake","power","airplane","vpn","record","wifi"]'
# Bluetooth, now first, to a whole row, which takes Hidden a row down.
move 656 254
click
sleep 0.3
arrow "$higher_x" 652
same "a whole row" "$(value .control.wide)" '["bluetooth"]'
shot control-wide
drag 594 480 530 254
same "what's left out, back" "$(value .control.hidden)" '[]'
same "the order, back" "$(value .control.tiles)" '["wifi","bluetooth","night","awake","power","airplane","vpn","record"]'
# A tile of one's own, by the button under the lanes, a row further down with
# Bluetooth's on a row of its own: its card is at the foot of the page.
move 1007 579
click
sleep 0.5
same "a tile made" "$(value .control.custom)" '[{"name":"Mine","command":"","check":"","icon":"play"}]'
move 700 400
notch 30
sleep 0.6
shot control-own
field 934 575 'touch somewhere'
same "what a click on it runs" "$(value '.control.custom[0].command')" '"touch somewhere"'
field 934 625 'true'
same "when it's on" "$(value '.control.custom[0].check')" '"true"'
arrow "$higher_x" 670
sleep 0.3
same "its sign, the next one" "$(value '.control.custom[0].icon')" '"power"'
field 934 525 'Fan'
same "its name" "$(value '.control.custom[0].name')" '"Fan"'
same "its place under its new name" "$(value '.control.tiles | last')" '"Fan"'
move 575 710
click
sleep 0.4
same "the tiles of one's own with it removed" "$(value .control.custom)" '[]'
same "the order without it" "$(value '.control.tiles | last')" '"record"'

step "The launcher's page"
printf '{ "tray": { "drawer": true }, "launcher": { "pinned": ["no.such.app"], "hidden": ["nor.this.one"] } }\n' >"$config.new"
chmod 644 "$config"
mv "$config.new" "$config"
sleep 0.5
page "$launcher_y"
shot launcher-page
# The first switch, then the second, and those of the two lists.
move "$switch_x" 234
click
sleep 0.3
same "frequent first" "$(value .launcher.usage)" false
move "$switch_x" 284
click
sleep 0.3
same "the last sums" "$(value .launcher.sums)" false
same "the sums are gone" "$(cat "$XDG_STATE_HOME/okaeri/sums.json")" '[]'
move "$switch_x" 372
click
sleep 0.3
same "the pinned" "$(value .launcher.pinned)" '[]'
# With the list empty a line says how, about as tall as the row was.
shot launcher-page-unpinned
move "$switch_x" 463
click
sleep 0.3
same "the hidden" "$(value .launcher.hidden)" '[]'

step "The clipboard's page"
page "$clipboard_y"
shot clipboard-page
move "$switch_x" 234
click
sleep 0.3
same "Enter pastes" "$(value .clipboard.paste)" true
arrow "$higher_x" 284
same "the rows" "$(value .clipboard.rows)" 200
# The wheel on a line goes along the list, and stops at its end.
move 700 284
wheel 1
same "the rows, by the wheel" "$(value .clipboard.rows)" 500
wheel -2
same "the rows, two notches down" "$(value .clipboard.rows)" 100
wheel -9
same "the rows at the end of the list" "$(value .clipboard.rows)" 50
arrow "$lower_x" 284
same "the rows past that" "$(value .clipboard.rows)" 50
arrow "$lower_x" 334
same "the history" "$(value .clipboard.keep)" 500

step "The notifications' page"
printf '{ "tray": { "drawer": true }, "notifications": { "rules": [{ "app": "Spam", "toast": false }] } }\n' >"$config.new"
mv "$config.new" "$config"
sleep 0.5
page "$notifications_y"
shot notifications-page
arrow "$higher_x" 260
same "how long" "$(value .notifications.timeout)" 8
# Down to the end, by the wheel: an app's row, and what its fold has.
move 700 500
notch 30
sleep 0.6
shot notifications-rules
move 1017 670
click
sleep 0.3
same "two things held back" "$(value .notifications.rules)" '[{"app":"Spam","toast":false,"history":false}]'
move 535 670
click
sleep 0.3
move 700 300
notch 30
sleep 0.6
shot notifications-rule-open
move "$switch_x" 598
click
sleep 0.3
same "its sound" "$(value '.notifications.rules[0].sound')" false

printf '{ "tray": { "drawer": true } }\n' >"$config.new"
mv "$config.new" "$config"
chmod 444 "$config"
sleep 0.5

step "It stays"
key Escape
wait_up 0
reloads=$(log | grep -c 'Reloading configuration' || true)
cat "$work/shell/shell.qml" >"$work/reloaded.qml"
cat "$work/reloaded.qml" >"$work/shell/shell.qml"
for _ in $(seq 50); do
	[ "$(log | grep -c 'Reloading configuration' || true)" -gt "$reloads" ] && break
	sleep 0.1
done
sleep 1
ipc settings toggle
wait_up 1
sleep 0.4
page "$tray_y"
shot reloaded
same "the drawer's switch after a reload" "$(knob reloaded "$drawer_y")" "$(knob drawer-off "$drawer_y")"

step "A window of its own"
# What closes a window closes this one, and not what's under it; a click
# elsewhere doesn't.
kitty --class under -o confirm_os_window_close=0 sh -c 'sleep 60' >/dev/null 2>&1 &
under=$!
for _ in $(seq 50); do
	[ "$(niri msg --json windows | jq '[.[] | select(.app_id == "under")] | length')" = 1 ] && break
	sleep 0.1
done
ipc settings toggle
sleep 0.2
ipc settings toggle
wait_up 1
sleep 0.4
same "the focus" "$(niri msg --json focused-window | jq -r .title)" Settings
move 1300 800
click
sleep 0.3
same "after a click elsewhere" "$(up)" 1
ipc settings toggle
wait_up 0
ipc settings toggle
wait_up 1
sleep 0.4
niri msg action close-window
wait_up 0
same "what's under it" "$(niri msg --json windows | jq '[.[] | select(.app_id == "under")] | length')" 1
kill "$under"
ipc settings toggle
wait_up 1
sleep 0.4
page "$tray_y"

step "A search"
# Every page's lines and cards, and the bar's parts' too: Enter goes to the
# first found, on its page, its part chosen for it.
search() {
	move "$menu_x" "$search_y"
	click
	type "$1"
	sleep 0.5
}
search awake
shot search-awake
key Return
sleep 0.8
same "the page found" "$(ipc settings shown)" "Control center"
shot search-found
search seconds
key Return
sleep 1.2
same "the page of a part's line" "$(ipc settings shown)" Bar
shot search-part
# One on a page's other leaf turns the page to it.
search 'way it comes'
key Return
sleep 0.8
same "the page of a line on another leaf" "$(ipc settings shown)" Wallpaper
shot search-leaf
[ "$(magick "$out/search-leaf.png" -crop 400x20+520+429 +repage -format '%k' info:)" -gt 1 ] || fail "the wallpaper's page didn't turn to the line"
# Escape empties the field first, and leaves the window there.
search nothing-of-the-kind
shot search-nothing
key Escape
sleep 0.3
same "the window, after Escape in the search" "$(up)" 1
shot search-emptied
[ "$(magick "$out/search-nothing.png" "$out/search-emptied.png" -compose difference -composite -crop 180x400+330+200 +repage -format '%[fx:maxima > 0.05]' info:)" = 1 ] || fail "Escape left what was looked for"
page "$tray_y"

step "Its size"
window_size() {
	niri msg --json windows | jq -r '[.[] | select(.title == "Settings")][0].layout.window_size | join("x")'
}
same "floating" "$(niri msg --json windows | jq '[.[] | select(.title == "Settings")][0].is_floating')" true
same "its size" "$(window_size)" 760x564
# Made another size, it keeps that, and has it again the next time.
niri msg action set-window-width 900
niri msg action set-window-height 600
sleep 1
same "the size kept" "$(jq -c . "$XDG_STATE_HOME/okaeri/settings-window.json")" '{"width":900,"height":600}'
ipc settings toggle
wait_up 0
ipc settings toggle
wait_up 1
sleep 0.4
same "its size the next time" "$(window_size)" 900x600
# Never smaller than it can be used at.
niri msg action set-window-width 300
sleep 0.6
[ "$(window_size | cut -dx -f1)" -ge 640 ] || fail "made $(window_size)"
# Back to the size the rest is written for.
ipc settings toggle
wait_up 0
printf '{"width":760,"height":564}\n' >"$XDG_STATE_HOME/okaeri/settings-window.json"
sleep 0.3
ipc settings toggle
wait_up 1
sleep 0.4
same "its size, back" "$(window_size)" 760x564

step "How it sounds"
page "$sounds_y"
shot sounds-page
arrow "$higher_x" 232
sleep 0.3
same "how loud the volume goes" "$(value .audio.max)" 125
arrow "$lower_x" 310
sleep 0.3
same "the sounds' volume" "$(value .sounds.volume)" 20
move "$switch_x" 410
click
sleep 0.3
same "notifications' sound" "$(value .sounds.notifications)" false

step "The on-screen display"
page "$osd_y"
shot osd-page
arrow "$higher_x" 232
sleep 0.3
same "where it shows" "$(value .osd.position)" '"middle"'
arrow "$higher_x" 282
sleep 0.3
same "for how long" "$(value .osd.duration)" 2
move "$switch_x" 332
click
sleep 0.3
same "in numbers" "$(value .osd.percent)" true
move "$switch_x" 622
click
sleep 0.3
same "what has none" "$(value .osd.hidden)" '["locks"]'

step "How the screen is recorded"
page "$display_y"
shot display-recording
arrow "$higher_x" 520
sleep 0.3
same "what's recorded" "$(value .recording.area)" '"region"'
arrow "$higher_x" 564
sleep 0.3
same "with what sound" "$(value .recording.audio)" '"system"'
field 942 608 '~/clips'
same "where the videos go" "$(value .recording.folder)" "\"$HOME/clips\""

step "The display's page"
page "$display_y"
shot display-page
move "$switch_x" 410
click
sleep 0.3
same "external monitors' brightness" "$(value .display.ddc)" true
arrow "$higher_x" 259
sleep 0.3
same "when the night light is" "$(value .nightLight.mode)" '"schedule"'
arrow "$higher_x" 309
sleep 0.3
same "how warm" "$(value .nightLight.temperature)" 4500
# A time that isn't one stays out.
move 994 359
click
wtype -M ctrl a -m ctrl
type '25:00'
key Return
sleep 0.3
same "a time that isn't" "$(value .nightLight.from)" null
wtype -M ctrl a -m ctrl
type '21:30'
key Return
sleep 0.3
same "from when" "$(value .nightLight.from)" '"21:30"'
arrow "$higher_x" 259
sleep 0.3
same "by the sun" "$(value .nightLight.mode)" '"sun"'
move 994 359
click
wtype -M ctrl a -m ctrl
type '52.5'
key Return
sleep 0.3
same "the latitude" "$(value .nightLight.latitude)" 52.5
shot display-sun

step "How it looks"
page "$look_y"
shot look
theme_own=$XDG_STATE_HOME/okaeri/theme.json
move "$switch_x" 260
click
sleep 0.3
same "blur behind panels" "$(jq -c .blur "$theme_own")" true
move "$switch_x" 310
click
sleep 0.3
same "blur behind notifications" "$(jq -c .toastBlur "$theme_own")" true
move "$switch_x" 360
click
sleep 0.3
same "blur behind the bar" "$(jq -c .barBlur "$theme_own")" true
# The rules for niri: the same file, with what's under the blur or without.
rules=$XDG_STATE_HOME/okaeri/niri.kdl
niri validate -c "$rules" 2>/dev/null || fail "niri can't read the rules"
grep -q 'okaeri-backdrop' "$rules" || fail "no rule for the backdrop"
! grep -q 'xray' "$rules" || fail "windows in the blur before they were asked for"
written=$(stat -c %Y.%y "$rules")
move "$switch_x" 410
click
sleep 0.3
same "windows in the blur" "$(jq -c .realBlur "$theme_own")" true
niri validate -c "$rules" 2>/dev/null || fail "niri can't read the rules with the blur"
[ "$(grep -c 'xray false' "$rules")" = 2 ] || fail "the rules: $(cat "$rules")"
[ "$(stat -c %Y.%y "$rules")" != "$written" ] || fail "the rules weren't written"
arrow "$higher_x" 455
same "how solid" "$(jq -c .opacity "$theme_own")" 80
move "$switch_x" 555
click
sleep 0.3
same "animations" "$(jq -c .animations "$theme_own")" false
# Solid as it opens, for niri's blur doesn't run then, and clear after that.
key Escape
wait_up 0
ipc settings toggle
same "the veil as it opens" "$(ipc settings veiled)" 1
sleep 1
same "the veil after that" "$(ipc settings veiled)" 0
wait_up 1
page "$look_y"
shot look-before
arrow "$higher_x" 655
same "the bar's height" "$(jq -c .barHeight "$theme_own")" 36
sleep 0.3
shot look-changed
# The bar went by it: its lower edge is further down.
[ "$(pixel look-changed 700 38)" != "$(pixel look-before 700 38)" ] || fail "the bar's height didn't change"
# Its colors, at the foot of the page: a palette, on at once, and the config's
# again; another by day; the accent from the wallpaper.
move 700 400
notch 30
sleep 0.6
shot look-colors
# The arrow back of a wider line.
wide_lower_x=862
bright() {
	magick "$out/$1.png" -format '%[fx:u.p{507,480}.r > 0.7]' info:
}
same "the window before" "$(bright look-colors)" 0
arrow "$higher_x" 614
arrow "$higher_x" 614
sleep 0.4
same "the palette" "$(jq -c .extends "$theme_own")" '"light"'
shot look-light
same "the window in a light palette" "$(bright look-light)" 1
arrow "$wide_lower_x" 614
arrow "$wide_lower_x" 614
sleep 0.4
same "the config's palette again" "$(jq -c .extends "$theme_own")" null
arrow "$higher_x" 659
sleep 0.4
same "another by day" "$(jq -c .auto "$theme_own")" '"time"'
shot look-timed
# The palette's line went, and this one is where that was.
arrow "$wide_lower_x" 609
sleep 0.4
same "one all day again" "$(jq -c .auto "$theme_own")" '"off"'
# To the foot again: the page has moved with what came and went.
move 700 400
notch 30
sleep 0.6
move "$switch_x" 704
click
sleep 0.3
same "the accent from the wallpaper" "$(jq -c .wallpaperAccent "$theme_own")" true
click
sleep 0.3
page "$tray_y"

step "Back to the config"
move "$menu_x" "$back_y"
click
sleep 0.3
same "the shell's file" "$(value .)" '{}'
same "the look's file" "$(jq -c . "$theme_own")" '{}'
! grep -q 'xray' "$rules" || fail "the rules kept the blur"
shot back
same "the drawer's switch" "$(knob back "$drawer_y")" "$on"
key Escape
wait_up 0

step "The rules at a start"
# With the theme saying so before the shell starts, as on a real desktop: a test
# that changes it later goes another way.
printf '{"realBlur":true}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 1
kill "$qs_pid"
wait "$qs_pid" 2>/dev/null || true
rm "$rules"
quickshell -p "$work/shell" >>"$out/qs.log" 2>&1 &
qs_pid=$!
sleep 3
[ "$(grep -c 'xray false' "$rules")" = 2 ] || fail "a start lost the theme's blur: $(cat "$rules")"
written=$(stat -c %y "$rules")
kill "$qs_pid"
wait "$qs_pid" 2>/dev/null || true
quickshell -p "$work/shell" >>"$out/qs.log" 2>&1 &
qs_pid=$!
sleep 3
[ "$(grep -c 'xray false' "$rules")" = 2 ] || fail "the next start lost the theme's blur: $(cat "$rules")"
same "the rules after a start with nothing new" "$(stat -c %y "$rules")" "$written"
