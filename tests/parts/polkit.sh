# The polkit dialog on demo()'s fake flow, by real keys and a real pointer: no
# agent exists here. Sourced by tests/part.sh.

secret=hunter2-xyzzy
other=correct-horse
# Where things are on the 1400x900 screen, with one identity.
field_y=451
buttons_y=528
cancel_x=713
authenticate_x=815
eye_x=853
# Parts of the picture: where the dialog can be at all, the start of what's in
# the field, short of the caret, the message, the buttons, the line under the
# field. Then that line with two identities, and the end of each of their rows.
middle=800x700+300+100
typed=60x20+541+441
message=344x24+528+390
buttons=344x20+528+518
note=344x20+528+482
note_below=344x20+528+534
row_one=24x20+842+408
row_two=24x20+842+446
# A part of the bar a card as tall as the screen would reach, short of the clock.
bar=120x34+515+0
# With a long message: its text, the mark next to it, and the buttons. With 40
# identities: the list, and the buttons. With those and a long note: the buttons.
long_text=330x280+528+260
long_mark=4x290+868+258
long_buttons_y=656
many_list=330x290+528+292
many_buttons_y=690
both_buttons_y=818
# The same at a scale of 1.5.
scaled_bar=190x51+420+0
scaled_authenticate_x=872
scaled_buttons_y=780

fail() {
	echo "polkit.sh: $*" >&2
	exit 1
}
count() {
	log | grep -cF "$1" || true
}
wait_count() {
	for _ in $(seq 50); do
		[ "$(count "$1")" -ge "$2" ] && return 0
		sleep 0.1
	done
	fail "wanted $2 of \"$1\", got $(count "$1")"
}
# Nothing new of TEXT: it's still at N a moment later.
still() {
	sleep 0.6
	[ "$(count "$1")" -eq "$2" ] || fail "wanted $2 of \"$1\", got $(count "$1")"
}
# Out of the way, so that the pointer isn't in the pictures that get compared.
park() {
	move 1390 890
}
# How much of two pictures differs, 0 for nothing: in a part of them, or the middle.
differ() {
	magick "$out/$1.png" "$out/$2.png" -crop "${3:-$middle}" +repage -metric AE -compare -format '%[distortion]' info:
}
# The same, but for rounding: the dialog alone is a tenth of the middle.
alike() {
	awk -v part="$(differ "$@")" 'BEGIN { exit !(part < 0.001) }'
}
same() {
	alike "$@" || fail "$1 and $2 differ: $(differ "$@")"
}
different() {
	if alike "$@"; then
		fail "$1 and $2 are the same"
	fi
}
# The pixels of a color in a part of a picture.
pixels() {
	magick "$out/$1.png" -crop "$2" +repage -alpha off -fuzz 8% -fill black +opaque "$3" -fill white -opaque "$3" -format '%[fx:int(mean*w*h+0.5)]' info:
}
# A part of a picture is more than one flat color, by more than a margin.
varies() {
	[ "$(magick "$out/$1.png" -crop "$2" +repage -format "%[fx:standard_deviation>$3]" info:)" = 1 ]
}
open_demo() {
	asked=$(count 'okaeri: asked')
	ipc polkit "${1:-demo}" ${2:+"$2"}
	wait_count 'okaeri: asked' "$((asked + 1))"
	sleep 0.3
}
# Closed: the picture is the one from before, as much as nothing else moved.
closed() {
	sleep 0.4
	park
	shot closed
	same desktop closed
}
# Ends the request at hand.
finish() {
	cancelled=$(count 'okaeri: cancelled')
	ipc polkit cancel
	wait_count 'okaeri: cancelled' "$((cancelled + 1))"
	closed
}
# Sends what's in the field, for the pointer at X Y on Authenticate if given,
# and waits for the first try's refusal.
turned_down() {
	submitted=$(count 'okaeri: submitted')
	failed=$(count 'okaeri: failed')
	if [ -n "${1:-}" ]; then
		move "$1" "$2"
		click
	else
		key Return
	fi
	wait_count 'okaeri: submitted' "$((submitted + 1))"
	wait_count 'okaeri: failed' "$((failed + 1))"
	sleep 0.5
}

park
shot desktop

# The whole way, in each theme: wrong password, then the right one.
run() {
	theme=$1
	error=$2
	submitted=$(count 'okaeri: submitted')
	failed=$(count 'okaeri: failed')
	succeeded=$(count 'okaeri: succeeded')

	# It asks a moment after it opens: keys right after that reach the field.
	asked=$(count 'okaeri: asked')
	ipc polkit demo
	sleep 0.1
	shot "$theme-waiting"
	wait_count 'okaeri: asked' "$((asked + 1))"
	sleep 0.5
	shot "$theme-open"
	different desktop "$theme-open"
	[ "$(pixels "$theme-open" "$note" "$error")" -eq 0 ] || fail "an error before any try"

	# Enter on nothing sends nothing.
	key Return
	still 'okaeri: submitted' "$submitted"

	# Hidden: two passwords of one length look the same.
	type aaaaaaaa
	shot "$theme-hidden-a"
	wtype -M ctrl a -m ctrl
	type WWWWWWWW
	shot "$theme-hidden-w"
	same "$theme-hidden-a" "$theme-hidden-w" "$typed"
	wtype -M ctrl a -m ctrl

	type "$secret"
	shot "$theme-typed"
	different "$theme-open" "$theme-typed" "$typed"

	# The eye shows it, and a click on it leaves the keys in the field. It stays
	# on for this try: the next one starts hidden again.
	move "$eye_x" "$field_y"
	click
	park
	shot "$theme-revealed"
	different "$theme-typed" "$theme-revealed" "$typed"

	key Return
	wait_count 'okaeri: submitted' "$((submitted + 1))"
	wait_count 'okaeri: failed' "$((failed + 1))"
	sleep 0.5
	shot "$theme-failed"
	[ "$(pixels "$theme-failed" "$note" "$error")" -gt 20 ] || fail "no error in the error color"

	# Still there, and empty: Enter has nothing to send, and undo gives nothing back.
	key Return
	wtype -M ctrl z -m ctrl
	sleep 0.2
	key Return
	still 'okaeri: submitted' "$((submitted + 1))"

	# The second try, by the pointer.
	type "$other"
	move "$authenticate_x" "$buttons_y"
	shot "$theme-authenticate"
	same "$theme-typed" "$theme-authenticate" "$typed"
	click
	wait_count 'okaeri: submitted' "$((submitted + 2))"
	wait_count 'okaeri: succeeded' "$((succeeded + 1))"
	closed
}

run dark '#ee6666'

# Escape cancels, and takes what was typed with it. The flow is gone at once,
# what it said stays through the fade out.
open_demo
type "$secret"
wtype -k Escape
for n in 1 2 3; do
	shot "dark-fading-$n"
done
wait_count 'okaeri: cancelled' 1
closed
# Whatever moment those pictures caught: while the dialog shows, so does the message.
for n in 1 2 3; do
	if varies "dark-fading-$n" "$buttons" 0.01 && ! varies "dark-fading-$n" "$message" 0.001; then
		fail "the message left before the dialog did"
	fi
done
submitted=$(count 'okaeri: submitted')
open_demo
key Return
still 'okaeri: submitted' "$submitted"

# So does the IPC call, and with nothing open it does nothing.
ipc polkit cancel
wait_count 'okaeri: cancelled' 2
closed
ipc polkit cancel
still 'okaeri: cancelled' 2

# Escape while the try is being checked, when the field is off.
open_demo
type "$secret"
failed=$(count 'okaeri: failed')
wtype -k Return -k Escape
wait_count 'okaeri: cancelled' 3
still 'okaeri: failed' "$failed"
closed

# A click elsewhere doesn't lose the request, and the keys stay with it.
open_demo
move 200 600
click
sleep 0.4
park
shot dark-clicked-away
different desktop dark-clicked-away
still 'okaeri: cancelled' 3
submitted=$(count 'okaeri: submitted')
failed=$(count 'okaeri: failed')
type "$secret"
key Return
wait_count 'okaeri: submitted' "$((submitted + 1))"
wait_count 'okaeri: failed' "$((failed + 1))"
sleep 0.5

# The Cancel button, by the pointer.
move "$cancel_x" "$buttons_y"
click
wait_count 'okaeri: cancelled' 4
closed

# Tab goes on to the buttons: Cancel first, Enter presses it.
open_demo
key Tab
shot dark-tab
key Return
wait_count 'okaeri: cancelled' 5
closed

# Two identities: a note up front, the first one chosen, the other a click away.
open_demo demoIdentities
park
shot dark-identities
varies dark-identities "$row_one" 0.01 || fail "no check on the first identity"
varies dark-identities "$row_two" 0.01 && fail "a check on the second identity"
varies dark-identities "$note_below" 0.01 || fail "no note"
[ "$(pixels dark-identities "$note_below" "#ee6666")" -eq 0 ] || fail "a note in the error color"
move 700 460
click
wait_log 'okaeri: identity root'
sleep 0.5
park
shot dark-identity-root
different dark-identities dark-identity-root
varies dark-identity-root "$row_two" 0.01 || fail "no check on the second identity"
varies dark-identity-root "$row_one" 0.01 && fail "a check left on the first identity"

# AuthFlow counts the session it left as failed, but no try was turned down.
varies dark-identity-root "$note_below" 0.01 || fail "the note left on a pick"
[ "$(pixels dark-identity-root "$note_below" "#ee6666")" -eq 0 ] || fail "an error on a pick"

# The field has the keys, and silence from PAM still gets an error, over what
# it said before.
type "$secret"
turned_down
shot dark-identity-failed
[ "$(pixels dark-identity-failed "$note_below" "#ee6666")" -gt 20 ] || fail "silence got no error"
finish

# The keys pick too: from the field back to the list, down, Enter. The field
# never went off, as AuthFlow keeps asking: the keys go back to it all the same.
chosen=$(count 'okaeri: identity root')
open_demo demoIdentities
wtype -M shift -k Tab -m shift
sleep 0.2
key Down
key Return
wait_count 'okaeri: identity root' "$((chosen + 1))"
type "$secret"
turned_down
finish

# A pick while a try is being checked ends the try: no word on it, and the keys
# are back in the field as it asks.
chosen=$(count 'okaeri: identity root')
submitted=$(count 'okaeri: submitted')
succeeded=$(count 'okaeri: succeeded')
failed=$(count 'okaeri: failed')
open_demo demoWith "$(jq -nc '{
	identities: [
		{ id: 1000, string: "alex", displayName: "Alex Doe", isGroup: false },
		{ id: 0, string: "root", displayName: "root", isGroup: false }
	],
	delay: 1500
}')"
type "$secret"
asked=$(count 'okaeri: asked')
key Return
move 700 460
click
wait_count 'okaeri: identity root' "$((chosen + 1))"
wait_count 'okaeri: asked' "$((asked + 1))"
sleep 0.2
still 'okaeri: failed' "$failed"
park
shot dark-identity-checking
[ "$(pixels dark-identity-checking "$note_below" "#ee6666")" -eq 0 ] || fail "an error for a try that got no answer"
type "$other"
key Return
wait_count 'okaeri: submitted' "$((submitted + 2))"
wait_count 'okaeri: succeeded' "$((succeeded + 1))"
closed

# What comes from outside can be any length: the field and the buttons stay on
# the screen, clear of the bar, and the rest scrolls. A long message first. The
# arrows scroll it with the keys left in the field, as the wheel can't be tried
# here (see tests/parts/clipboard.sh). The pointer gets to both buttons.
long=$(jq -nc '{ message: [range(400) | "--flag=\(.)"] | join(" ") }')
many=$(jq -nc '{ identities: [range(40) | { id: ., string: "user\(.)", displayName: "User \(.)", isGroup: false }] }')
both=$(jq -nc --argjson long "$long" --argjson many "$many" '$long + $many + { supplementaryMessage: [range(200) | "note"] | join(" ") }')

open_demo demoWith "$long"
park
shot dark-long
same closed dark-long "$bar"
varies dark-long "$long_mark" 0.01 || fail "no mark on a long message"
key Down
sleep 0.8
shot dark-long-down
different dark-long dark-long-down "$long_text"
different dark-long dark-long-down "$long_mark"
type "$secret"
turned_down "$authenticate_x" "$long_buttons_y"
cancelled=$(count 'okaeri: cancelled')
move "$cancel_x" "$long_buttons_y"
click
wait_count 'okaeri: cancelled' "$((cancelled + 1))"
closed

# The next one starts at the top.
open_demo demoWith "$long"
park
shot dark-long-again
same dark-long dark-long-again "$long_text"
finish

# 40 identities: the keys get down the list, and the row picked stays in sight.
chosen=$(count 'okaeri: identity user30')
open_demo demoWith "$many"
park
shot dark-many
same closed dark-many "$bar"
wtype -M shift -k Tab -m shift
sleep 0.2
for _ in $(seq 30); do
	wtype -k Down
done
sleep 0.3
key Return
wait_count 'okaeri: identity user30' "$((chosen + 1))"
sleep 0.5
shot dark-many-picked
different dark-many dark-many-picked "$many_list"
type "$secret"
turned_down
shot dark-many-failed
same dark-many-picked dark-many-failed "$many_list"
cancelled=$(count 'okaeri: cancelled')
move "$cancel_x" "$many_buttons_y"
click
wait_count 'okaeri: cancelled' "$((cancelled + 1))"
closed

# All of it at once, with a long note.
open_demo demoWith "$both"
park
shot dark-both
same closed dark-both "$bar"
type "$secret"
turned_down "$authenticate_x" "$both_buttons_y"
finish

# The light theme, live.
printf '{"extends":"light"}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
park
shot desktop
run light '#c62828'
open_demo demoIdentities
park
shot light-identities
finish

# Without animations the panel closes at once, and opens again.
printf '{"animations":false}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
park
shot desktop
open_demo
shot no-animations-open
different desktop no-animations-open
cancelled=$(count 'okaeri: cancelled')
key Escape
wait_count 'okaeri: cancelled' "$((cancelled + 1))"
closed
open_demo
finish

# A key moves the message by a step and that's all: a flick would go on by
# itself.
open_demo demoWith "$long"
park
shot no-animations-long
wtype -k Down
sleep 0.1
shot no-animations-step
different no-animations-long no-animations-step "$long_text"
sleep 0.5
shot no-animations-stopped
same no-animations-step no-animations-stopped "$long_text"
key Up
shot no-animations-back
same no-animations-long no-animations-back "$long_text"
finish

# A click elsewhere takes the window off the screen at once: it's back, with
# what was typed and the keys, and the request goes on.
cancelled=$(count 'okaeri: cancelled')
open_demo
type "$secret"
move 200 600
click
sleep 0.4
park
shot no-animations-clicked-away
different desktop no-animations-clicked-away
different no-animations-open no-animations-clicked-away "$typed"
still 'okaeri: cancelled' "$cancelled"
turned_down
finish

# A bigger scale leaves less room, and all of it still fits.
printf '{"scale":1.5}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
park
shot scaled-closed
open_demo demoWith "$both"
park
shot scaled-both
same scaled-closed scaled-both "$scaled_bar"
type "$secret"
turned_down "$scaled_authenticate_x" "$scaled_buttons_y"
finish

# No password anywhere, and no agent was ever made.
if grep -rqaF -e "$secret" -e "$other" "$out/qs.log" "$XDG_RUNTIME_DIR/quickshell"; then
	fail "a password got into a log"
fi
if log | grep -qF 'polkit agent up'; then
	fail "an agent was made in a test"
fi
