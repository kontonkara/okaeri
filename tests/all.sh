#!/bin/sh
# Every test, one after another: each part with the bar, the whole shell, and
# those two with OKAERI_GUEST=1, the whole shell as ./try has it, and install.sh.
# It goes on past a failure, and says which at the end, with how long each took.
# Each one's output is in <out>/<name>.log, and what it left in <out>/<name>. In
# the repo:
#
#   tests/tools.sh tests/all.sh <out>                  all of them
#   tests/tools.sh tests/all.sh <out> settings shell   only those, by their names
set -u

out=${1:?usage: all.sh <out> [name...]}
shift
mkdir -p "$out"
failed=

# Whether test $1 is one asked for: all of them, with none named.
wanted() {
	[ "$#" -eq 1 ] && return 0
	name=$1
	shift
	for other in "$@"; do
		[ "$other" = "$name" ] && return 0
	done
	return 1
}

# Runs the rest of the line as test $1.
run() {
	name=$1
	shift
	started=$(date +%s)
	if "$@" >"$out/$name.log" 2>&1; then
		echo "passed: $name ($(($(date +%s) - started)) s)"
	else
		echo "FAILED: $name ($(($(date +%s) - started)) s)"
		failed="$failed $name"
	fi
}

for script in tests/parts/*.sh; do
	part=$(basename "$script" .sh)
	wanted "$part" "$@" || continue
	case $part in
	bar) root=Scope ;;
	clipboard) root=ClipboardPanel ;;
	control) root=ControlCenter ;;
	dock) root=Docks ;;
	hooks) root=Hooks ;;
	idle) root=Idle ;;
	keys) root=Keys ;;
	launcher) root=Launcher ;;
	notifications) root=NotificationCenter ;;
	osd) root=Osd ;;
	polkit) root=PolkitDialog ;;
	session) root=SessionMenu ;;
	settings) root=SettingsWindow ;;
	wallpaper) root=Wallpaper ;;
	*)
		echo "FAILED: $part has no root type here"
		failed="$failed $part"
		continue
		;;
	esac
	run "$part" tests/part.sh "$part" "$root" "$out/$part" "$script"
done
! wanted notifications-guest "$@" || run notifications-guest env OKAERI_GUEST=1 tests/part.sh notifications NotificationCenter "$out/notifications-guest" tests/parts/notifications.sh
! wanted shell "$@" || run shell tests/part.sh "" "" "$out/shell" tests/shell.sh
! wanted shell-guest "$@" || run shell-guest env OKAERI_GUEST=1 OKAERI_GALLERY=1 tests/part.sh "" "" "$out/shell-guest" tests/shell.sh
! wanted install "$@" || run install tests/install.sh "$out/install"

[ -z "$failed" ] || {
	echo "failed:$failed"
	exit 1
}
echo "all passed"
