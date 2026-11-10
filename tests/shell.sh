# The whole shell as shell.qml has it, sourced by part.sh with an empty part:
# every panel by IPC and by the bar's buttons, in both themes. With
# OKAERI_GUEST=1 in the environment it's what ./try runs, next to another shell.

fail() {
	echo "shell: $1" >&2
	exit 1
}
step() {
	echo "shell: $1" >&2
}
settle() {
	sleep 0.4
}

# The panels, by their IPC targets.
panels="launcher clipboard control notifications"

# How many layers okaeri-$1 has up.
up() {
	niri msg --json layers | jq "[.[] | select(.namespace == \"okaeri-$1\")] | length"
}
# Until $2 of them are up, or fails after 3 s, saying $3.
wait_up() {
	for _ in $(seq 30); do
		[ "$(up "$1")" = "$2" ] && return 0
		sleep 0.1
	done
	fail "$3: $(up "$1") of okaeri-$1 up, not $2"
}
has_server() {
	dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
		org.freedesktop.DBus.NameHasOwner string:org.freedesktop.Notifications | grep -q 'boolean true'
}
theme() {
	printf '%s' "$1" >"$XDG_CONFIG_HOME/okaeri/theme.json"
	sleep 0.5
}
# Whether two shots show the left end of a panel alike. The rest can be the
# machine's own volume, which someone may be changing.
alike() {
	[ "$(magick "$out/$1.png" "$out/$2.png" -compose difference -composite \
		-crop 60x120+1016+42 +repage -format '%[fx:maxima * 255 < 8]' info:)" = 1 ]
}
notifications() {
	ipc notifications state | jq -e "$1" >/dev/null
}

# Every panel up and down again, the dialog and the card, with a shot of each.
tour() {
	shot "$1-bar"
	for target in $panels; do
		ipc "$target" toggle
		wait_up panel 1 "$target by IPC"
		settle
		shot "$1-$target"
		ipc "$target" toggle
		wait_up panel 0 "$target by IPC"
	done
	ipc polkit demo
	wait_up panel 1 "the dialog by IPC"
	sleep 0.8
	shot "$1-polkit"
	ipc polkit cancel
	wait_up panel 0 "the dialog by IPC"
	ipc osd show volume 0.5
	wait_up osd 1 "the card by IPC"
	settle
	shot "$1-osd"
	wait_up osd 0 "the card by itself"
}

# Calls on each other's heels and on top of each other, at first before a panel
# ever had a frame.
rapid() {
	for target in $panels; do
		ipc "$target" toggle &
		first=$!
		ipc "$target" toggle
		wait "$first"
		settle
		wait_up panel 0 "$target, two calls at once"
		for _ in 1 2 3; do
			ipc "$target" toggle
		done
		wait_up panel 1 "$target, three calls"
		settle
		key Escape
		wait_up panel 0 "$target, Escape"
		for _ in 1 2 3 4 5 6; do
			ipc "$target" toggle
		done
		settle
		wait_up panel 0 "$target, six calls"
	done
	for _ in 1 2 3; do
		ipc polkit demo
		ipc polkit cancel
	done
	settle
	wait_up panel 0 "the dialog, three times"
	for level in 0.1 0.2 0.3 0.4 0.5; do
		ipc osd show volume "$level"
	done
	wait_up osd 1 "the card, five calls"
	wait_up osd 0 "the card after five calls"
}

# Tests have no agent either, and read the dialog's loader all the same.
agent() {
	log | grep -qF 'okaeri: polkit agent up'
}

# Next to another shell: nothing that only one can hold, and the rest works.
if [ "${OKAERI_GUEST:-}" = 1 ]; then
	! has_server || fail "a notification server next to another shell"
	rapid
	tour guest
	! has_server || fail "a notification server came up"
	! agent || fail "a polkit agent came up"
	return 0
fi

has_server || fail "no notification server"

step "Quick repeats"
rapid

step "Every panel, dark"
tour dark

step "The buttons on the bar"
move 300 600
settle
shot bar
set -- $(lane bar)
[ "$#" -ge 3 ] || fail "the bar shows $# things right of the clock: $*"
bell=$1
clipboard=$2
shift $(($# - 1))
control=$1
# Panel $1's button at $2 opens it, the same as by IPC. It's over the bar then,
# so the same click is one elsewhere, and closes it.
press() {
	move "$2" 16
	click
	wait_up panel 1 "the $1 button"
	settle
	shot "click-$1"
	alike "click-$1" "dark-$1" || fail "the $1 button opened something else"
	click
	wait_up panel 0 "a click over the $1 button"
}
press notifications "$bell"
press clipboard "$clipboard"
press control "$control"
# How wide what shows under the pointer is at $1, above the icon. The bell at
# rest is as round as the rest of them.
under() {
	move "$1" 16
	settle
	shot under
	magick "$out/under.png" -crop "60x1+$(($1 - 30))+7" +repage -colorspace Gray -threshold 1% \
		-format '%[fx:int(mean*w+0.5)]' info:
}
[ "$(under "$bell")" = "$(under "$clipboard")" ] || fail "the bell is another shape under the pointer"
move 300 600

step "Two panels"
ipc launcher toggle
ipc control toggle
wait_up panel 2 "two panels"
settle
shot two-panels
key Escape
wait_up panel 1 "Escape from two panels"
key Escape
wait_up panel 0 "Escape from the other one"

step "Where the buttons are"
# Whether what's at $2 150 in shot $1 is the desktop, as it is at the middle of
# the screen's lower edge.
desktop() {
	[ "$(magick "$out/$1.png" -format "%[hex:u.p{$2,150}]" info:)" = "$(magick "$out/$1.png" -format '%[hex:u.p{700,880}]' info:)" ]
}
config=$XDG_CONFIG_HOME/okaeri/settings.json
printf '{ "bar": { "left": ["workspaces", "control"], "center": ["clock", "clipboard"], "right": ["notifications"] } }' >"$config"
sleep 0.5
ipc control toggle
wait_up panel 1 "the control center on the left"
settle
shot left-control
desktop left-control 200 && fail "the control center isn't on the left"
desktop left-control 1200 || fail "the control center is still on the right"
ipc clipboard toggle
wait_up panel 2 "the clipboard in the middle, beside the control center"
settle
shot middle-clipboard
desktop middle-clipboard 700 && fail "the clipboard isn't in the middle"
key Escape
key Escape
wait_up panel 0 "Escape from the left and the middle"
printf '{}' >"$config"
sleep 0.5

step "Two panels in one place"
# The second takes over, keys and all.
ipc clipboard toggle
wait_up panel 1 "the clipboard"
settle
ipc control toggle
settle
wait_up panel 1 "two panels in a corner"
shot one-place
alike one-place dark-control || fail "the control center isn't what's left in the corner"
key Escape
wait_up panel 0 "Escape from the corner"
# The dialog takes the launcher's place, and nothing takes the dialog's.
ipc launcher toggle
wait_up panel 1 "the launcher"
settle
ipc polkit demo
settle
wait_up panel 1 "the dialog over the launcher"
ipc launcher toggle
wait_up panel 2 "the launcher over the dialog"
settle
key Escape
wait_up panel 1 "Escape from the launcher over the dialog"
ipc polkit cancel
wait_up panel 0 "the dialog after the launcher"

step "A panel in the toasts' corner"
ipc control toggle
wait_up panel 1 "the control center"
settle
shot panel-alone
timeout 30 notify-send -a Mail "Beside" "It goes next to the panel."
wait_up toasts 1 "a toast with the control center open"
sleep 0.5
shot beside
alike panel-alone beside || fail "a toast over the control center"
[ "$(magick "$out/panel-alone.png" "$out/beside.png" -compose difference -composite \
	-crop 370x60+628+42 +repage -format '%[fx:maxima * 255 > 8]' info:)" = 1 ] || fail "no toast beside the panel"

# A right click on it, where it went to: the window's mask went along.
move 987 63
click right
wait_up toasts 0 "a right click on a toast beside the panel"
[ "$(up panel)" = 1 ] || fail "the panel closed with a click on a toast"

# It comes up beside it, and goes back as the panel closes.
timeout 30 notify-send -a Mail "Back" "It goes back to the corner."
wait_up toasts 1 "another toast with the control center open"
settle
key Escape
wait_up panel 0 "Escape from the control center"
sleep 0.5
shot corner
[ "$(magick "$out/beside.png" "$out/corner.png" -compose difference -composite \
	-crop 60x60+1026+42 +repage -format '%[fx:maxima * 255 > 8]' info:)" = 1 ] || fail "the toast stayed aside"
ipc notifications clear
wait_up toasts 0 "the toast after clear"

step "The settings from the control center"
move 300 600
settle
shot no-control
ipc control toggle
wait_up panel 1 "the control center"
settle
shot control-open
# The settings' button is in the panel's top row, at its right but for the
# session menu's; the panel's right edge is 10 px in from the screen's.
move 1331 70
click
sleep 0.6
wait_up panel 0 "the control center, gone for the settings"
settings_up() {
	niri msg --json windows | jq '[.[] | select(.title == "Settings")] | length'
}
[ "$(settings_up)" = 1 ] || fail "no settings window"
# Out of where the control center was.
move 300 850
sleep 0.3
shot settings-open
[ "$(magick "$out/no-control.png" "$out/settings-open.png" -compose difference -composite \
	-crop 1x700+700+100 +repage -format '%[fx:maxima * 255 > 8]' info:)" = 1 ] || fail "no settings in the middle"
[ "$(magick "$out/no-control.png" "$out/settings-open.png" -compose difference -composite \
	-crop 160x100+1220+60 +repage -format '%[fx:maxima * 255 > 8]' info:)" = 0 ] || fail "the control center stayed"
key Escape
sleep 0.3
[ "$(settings_up)" = 0 ] || fail "the settings after Escape"

step "The session from the launcher"
ipc launcher toggle
wait_up panel 1 "the launcher"
settle
type reboot
sleep 0.2
shot session-row
key Return
sleep 0.5
wait_up panel 1 "the session menu from the launcher"
shot session-from-launcher
key Escape
sleep 0.3
[ "$(up panel)" = 1 ] || fail "Escape on the countdown closed the menu"
key Escape
wait_up panel 0 "the session menu, closing"
! log | grep -q "okaeri: dry: session" || fail "the session did something"

step "What they're for"
timeout 30 notify-send -a Mail "Hello" "A toast over the whole shell."
wait_up toasts 1 "a notification"
settle
shot toast
notifications '.history == 1 and .unread == 1' || fail "the notification isn't in the history"
for _ in $(seq 80); do
	[ "$(up toasts)" = 0 ] && break
	sleep 0.1
done
wait_up toasts 0 "the toast by itself"
settle
shot bell-unread
bell=$(lane bell-unread | head -n 1)
move "$bell" 16
click
wait_up panel 1 "the bell"
settle
shot bell-open
notifications '.panel and .unread == 0' || fail "the bell didn't open the history"
key Escape
wait_up panel 0 "Escape from the history"
ipc notifications clear

printf 'copied here' | wl-copy
sleep 0.5
ipc clipboard toggle
wait_up panel 1 "the clipboard"
settle
shot clipboard-entry
key Return
wait_up panel 0 "a row put back"
[ "$(wl-paste -n)" = "copied here" ] || fail "the clipboard has something else"

ipc launcher toggle
wait_up panel 1 "the launcher"
settle
type kitty
key Return
wait_log 'okaeri: dry: launch kitty'
wait_up panel 0 "a launch"

step "Every panel, light"
theme '{"extends":"light"}'
tour light

step "No animations"
theme '{"animations":false}'
rapid
tour still

step "Square"
theme '{"radius":0}'
ipc control toggle
wait_up panel 1 "the control center"
settle
key Tab
sleep 0.2
shot square
# The ring, on the settings' button, has a corner where it's whitest: all that's white there is the ring
# and the icon in it.
[ "$(magick "$out/square.png" -crop 42x46+1310+48 +repage -fill black +opaque white -trim +repage \
	-format '%[fx:p{0,0}.r>0.5]' info:)" = 1 ] ||
	fail "the ring around a square button isn't square"
key Escape
wait_up panel 0 "the square control center"

step "Bigger"
theme '{"scale":1.5}'
tour bigger

step "Whole pixels"
move 300 600
# The first $3 colors of shot $1 along crop $2, with $4 to turn it around. An
# edge on a fraction of a pixel has more of them, and others.
into() {
	magick "$out/$1.png" -crop "$2" +repage ${4:-} txt:- | awk 'NR > 1 { print $3 }' | uniq | head -n "$3" | tr '\n' ' '
}
# The same from row $4 down, from the bottom up and in from the sides, to $2 $3
# on a straight stretch of what's on the screen.
frame() {
	into "$1" "1x$(($3 - $4))+$2+$4" "$5"
	into "$1" "1x$((900 - $3))+$2+$3" "$5" -flip
	into "$1" "$2x1+0+$3" "$5"
	into "$1" "$((1400 - $2))x1+$2+$3" "$5" -flop
}
# Where a panel at the right of shot $1 starts, along row 300.
panel_left() {
	magick "$out/$1.png" -crop 500x1+900+300 +repage txt:- | awk 'NR == 2 { desk = $3 } NR > 1 && $3 != desk { split($1, at, ","); print 900 + at[1]; exit }'
}
# What's on the screen at theme scale $1 from row $2 on, as shots $3-name.
framed() {
	theme "{\"scale\":$1}"
	ipc control toggle
	wait_up panel 1 "the control center at $1"
	settle
	shot "$3-control"
	key Escape
	wait_up panel 0 "the control center at $1"
	ipc launcher toggle
	wait_up panel 1 "the launcher at $1"
	settle
	shot "$3-launcher"
	key Escape
	wait_up panel 0 "the launcher at $1"
	ipc polkit demo
	wait_up panel 1 "the dialog at $1"
	sleep 0.8
	shot "$3-polkit"
	ipc polkit cancel
	wait_up panel 0 "the dialog at $1"
	timeout 30 notify-send -a Mail "One" "A toast."
	timeout 30 notify-send -a Mail "Two" "A toast."
	wait_up toasts 1 "toasts at $1"
	settle
	shot "$3-toasts"
	ipc notifications clear
	wait_up toasts 0 "toasts at $1"
	# The control center by its edges, short of what's in it: down its middle from
	# the bar to its top, up from the bottom of the screen to its bottom, and in to
	# its sides.
	left=$(panel_left "$3-control")
	middle=$(((left + 1390) / 2))
	echo "control: $(into "$3-control" "1x$((300 - $2))+$middle+$2" 5) | $(into "$3-control" "1x600+$middle+300" 3 -flip) | $(into "$3-control" "$((left + 4))x1+0+300" 3 -flop) | $(into "$3-control" "20x1+1380+300" 3 -flop)"
	echo "launcher: $(frame "$3-launcher" 700 450 "$2" 3)"
	echo "dialog: $(frame "$3-polkit" 700 450 "$2" 3)"
	echo "toasts: $(frame "$3-toasts" 1200 90 "$2" 3)"
	# Past the text on them, down the whole stack.
	echo "stack: $(into "$3-toasts" "1x$((900 - $2))+1326+$2" 20)"
}
framed 1 35 whole-1 >"$out/frames-1"
for scale in 1.25 1.3; do
	framed "$scale" 45 "whole-$scale" >"$out/frames-$scale"
	diff "$out/frames-1" "$out/frames-$scale" >&2 || fail "the edges at a scale of $scale aren't those of 1"
done

step "Blur"
# How bright shot $1 is at $2 $3.
bright() {
	magick "$out/$1.png" -format "%[fx:int(p{$2,$3}.r*255)]" info:
}
# A wallpaper that's black up to $1, and white after it.
edge() {
	magick -size "$1x900" xc:black -size "$((1400 - $1))x900" xc:white +append "$work/edge-$1.png"
	printf '{ "wallpaper": { "path": "%s/edge-%s.png", "fade": 0 } }\n' "$work" "$1" >"$config"
	sleep 0.5
}
# Panel $1 up for shot $2, and down again.
glimpse() {
	ipc "$1" toggle
	wait_up panel 1 "$1 for $2"
	settle
	shot "$2"
	key Escape
	wait_up panel 0 "Escape from $1 for $2"
}
# The edges are just inside the panels' left ends, under their padding: only
# blur brings light to the black side, and it has to reach that far.
theme '{}'
edge 1030
glimpse control opaque
[ "$(bright opaque 1036 50)" = 0 ] || fail "the wallpaper shows through without blur"
theme '{"blur":true}'
glimpse control glass
[ "$(bright glass 1024 50)" -gt 8 ] || fail "no blur at the left end of a panel in a corner"
[ "$(bright glass 1036 50)" -gt "$(bright glass 1024 50)" ] || fail "no wallpaper through the panel"
edge 410
glimpse launcher glass-middle
[ "$(bright glass-middle 405 450)" -gt 8 ] || fail "no blur at the left end of a panel in the middle"
# Its edge over white is as dark as the rest of it, near enough: no light line.
edge 1
glimpse launcher glass-white
[ "$(bright glass-white 400 450)" -lt 120 ] || fail "a light line around a panel: $(bright glass-white 400 450)"
# The bar: the same, and on its own, over the wallpaper's edge.
theme '{}'
edge 700
sleep 0.5
shot bar-opaque
[ "$(bright bar-opaque 760 34)" = 0 ] || fail "the wallpaper shows through the bar without blur"
theme '{"barBlur":true}'
shot bar-glass
[ "$(bright bar-glass 690 34)" -gt 8 ] || fail "no blur behind the bar"
[ "$(bright bar-glass 760 34)" -gt "$(bright bar-glass 690 34)" ] || fail "no wallpaper through the bar"
glimpse control bar-glass-panel
[ "$(bright bar-glass-panel 1036 50)" = 0 ] || fail "the panels went for the bar's blur"
if [ "${OKAERI_GUEST:-}" != 1 ]; then
	# A toast, at its left end as a panel.
	theme '{"toastBlur":true}'
	edge 1030
	notify-send Glass "over the wallpaper"
	settle
	shot toast-glass
	[ "$(bright toast-glass 1024 50)" -gt 8 ] || fail "no blur at the left end of a toast"
	[ "$(bright toast-glass 1036 50)" -gt "$(bright toast-glass 1024 50)" ] || fail "no wallpaper through a toast"
	ipc notifications clear
	settle
	# The windows under it, which only the rules niri reads from the shell let in.
	edge 1399
	DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null kitty --title under-glass --config NONE -o background=#ffffff -o confirm_os_window_close=0 sleep 30 &
	under=$!
	sleep 1.5
	niri msg action maximize-column
	theme '{"blur":true}'
	sleep 1.5
	# The settings window for shot $1, with its veil gone.
	settings_glimpse() {
		ipc settings toggle
		sleep 1.2
		shot "$1"
		ipc settings toggle
		sleep 0.5
	}
	glimpse control wallpaper-glass
	[ "$(bright wallpaper-glass 1036 50)" = 0 ] || fail "a window in the blur with no rule for it"
	settings_glimpse wallpaper-settings
	# Under its pages, where the window has nothing on it.
	[ "$(bright wallpaper-settings 300 700)" = 0 ] || fail "a window in the settings' blur with no rule for it"
	theme '{"blur":true,"realBlur":true}'
	sleep 1.5
	glimpse control window-glass
	[ "$(bright window-glass 1036 50)" -gt 8 ] || fail "no window in the blur: niri didn't take the rules"
	settings_glimpse window-settings
	[ "$(bright window-settings 300 700)" -gt 8 ] || fail "no window in the settings' blur"
	kill "$under"
	wait "$under" 2>/dev/null || true
	sleep 0.4
fi
theme '{}'
printf '{}' >"$config"

step "A reload with a panel up"
theme '{}'
ipc control toggle
wait_up panel 1 "the control center"
printf '\n// Once more.\n' >>"$work/shell/shell.qml"
wait_log 'Reloading configuration'
sleep 1
wait_up panel 0 "a reload"
has_server || fail "no notification server after a reload"
rapid
tour reloaded

wait_up toasts 0 "the end"
! agent || fail "a polkit agent came up"
