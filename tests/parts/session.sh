# The session menu by the keys: every row, what it would do showing as a dry line
# in the log. Which rows there are is up to the machine, and logind says.

fail() {
	echo "session: $1" >&2
	exit 1
}

up() {
	niri msg --json layers | jq -e 'any(.[]; .namespace == "okaeri-panel")' >/dev/null
}
wait_up() {
	for _ in $(seq 30); do
		up && return 0
		sleep 0.1
	done
	fail "it didn't open"
}
wait_gone() {
	for _ in $(seq 30); do
		up || return 0
		sleep 0.1
	done
	fail "$1"
}
open() {
	ipc session toggle
	wait_up
	sleep 0.4
}
countdown() {
	printf '{ "session": { "countdown": %s } }\n' "$1" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	sleep 0.3
}
lines() {
	log | sed -n 's/.*okaeri: dry: //p'
}
seen=0
# The next dry line is $1, and the only one.
said() {
	seen=$((seen + 1))
	for _ in $(seq 40); do
		[ "$(lines | wc -l)" -ge "$seen" ] && break
		sleep 0.1
	done
	got=$(lines | sed -n "${seen}p")
	[ "$got" = "$1" ] || fail "wanted \"$1\", got \"$got\""
	[ "$(lines | wc -l)" -eq "$seen" ] || fail "more than \"$1\": $(lines | tail -n 1)"
}
silent() {
	[ "$(lines | wc -l)" -eq "$seen" ] || fail "$1: $(lines | tail -n 1)"
}

can() {
	busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager "$1" |
		grep -qE '"(yes|challenge)"'
}
rows=lock
! can CanSuspend || rows="$rows suspend"
rows="$rows logout reboot"
! can CanRebootToFirmwareSetup || rows="$rows firmware"
rows="$rows poweroff"

# Each row: nothing happens on picking it, and Enter doesn't wait.
downs=0
for row in $rows; do
	open
	[ "$downs" != 0 ] || shot menu
	for _ in $(seq "$downs"); do
		key Down
	done
	key Return
	sleep 0.2
	silent "$row didn't wait"
	[ "$downs" != 0 ] || shot counting
	key Return
	said "session $row"
	wait_gone "$row left it open"
	downs=$((downs + 1))
done

# Escape takes it back to the list, and the next one closes.
open
key Return
key Escape
up || fail "Escape on a countdown closed it"
key Escape
wait_gone "Escape on the list left it open"
silent "after Escape"

# The buttons: Cancel, then Now.
open
key Return
key Tab
key Return
up || fail "Cancel closed it"
silent "after Cancel"
key Return
key Tab
key Tab
key Return
said "session lock"
wait_gone "Now left it open"

# It runs out by itself.
countdown 1
open
key Return
said "session lock"
wait_gone "the countdown left it open"

# Closing it takes the action back.
open
key Return
ipc session toggle
wait_gone "toggle left it open"
sleep 1.4
silent "after closing"

# Without a countdown it's done at once.
countdown 0
open
key Return
said "session lock"
wait_gone "no countdown left it open"

echo "session: all good" >&2
