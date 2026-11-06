#!/bin/sh
# Every test, one after another: each part with the bar, the whole shell, and
# those two with OKAERI_GUEST=1, the whole shell as ./try has it. It goes on
# past a failure, and says which at the end. Each one's output is in
# <out>/<name>.log, and what it left in <out>/<name>. In the repo:
#
#   tests/tools.sh tests/all.sh <out>
set -u

out=${1:?usage: all.sh <out>}
mkdir -p "$out"
failed=

# Runs the rest of the line as test $1.
run() {
	name=$1
	shift
	if "$@" >"$out/$name.log" 2>&1; then
		echo "passed: $name"
	else
		echo "FAILED: $name"
		failed="$failed $name"
	fi
}

for script in tests/parts/*.sh; do
	part=$(basename "$script" .sh)
	case $part in
	bar) root=Scope ;;
	clipboard) root=ClipboardPanel ;;
	control) root=ControlCenter ;;
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
run notifications-guest env OKAERI_GUEST=1 tests/part.sh notifications NotificationCenter "$out/notifications-guest" tests/parts/notifications.sh
run shell tests/part.sh "" "" "$out/shell" tests/shell.sh
run shell-guest env OKAERI_GUEST=1 OKAERI_GALLERY=1 tests/part.sh "" "" "$out/shell-guest" tests/shell.sh

[ -z "$failed" ] || {
	echo "failed:$failed"
	exit 1
}
echo "all passed"
