# The user's commands for when things happen: what would run shows as dry lines
# in the log, by what happened. The battery is a probe's here, a file only this
# test has, put into the shell's copy. Then the colors in other apps' files, as
# templates have them.

fail() {
	echo "hooks: $1" >&2
	exit 1
}
ran() {
	log | grep -c "okaeri: dry: hook $1" || true
}
# The command for $1 was asked for once more than the $2 times before.
once_more() {
	for _ in $(seq 30); do
		[ "$(ran "$1")" -gt "$2" ] && break
		sleep 0.1
	done
	[ "$(ran "$1")" = $(($2 + 1)) ] || fail "the command for \"$1\" ran $(ran "$1") times, not $(($2 + 1))"
}
settings() {
	printf '%s\n' "$1" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	sleep 0.4
}

cat >"$work/Probe.qml" <<'QML'
import QtQuick
import Quickshell.Io
import qs.services

IpcHandler {
	target: "probe"

	function battery(charge: int, draining: bool): void {
		Power.charge = charge;
		Power.draining = draining;
	}
}
QML
sed 's/^\tHooks {}$/\tHooks {}\n\n\tProbe {}/' "$work/shell/shell.qml" >"$work/shell.qml"
grep -q 'Probe {}' "$work/shell.qml" || fail "no probe in the shell"
mv "$work/Probe.qml" "$work/shell/Probe.qml"
# In place: a file put over it isn't always seen.
cat "$work/shell.qml" >"$work/shell/shell.qml"
for _ in $(seq 50); do
	[ -z "$(ipc probe battery 100 false 2>&1)" ] && break
	sleep 0.2
done

# With no commands nothing runs, and what things are like as the shell comes up is
# no change.
sleep 2.5
[ "$(log | grep -c 'okaeri: dry: hook')" = 0 ] || fail "a command with none set: $(log | grep 'dry: hook' | tail -n 1)"

settings '{ "hooks": { "charger": "true", "battery": "true", "low": "true", "colors": "true", "wallpaper": "true" } }'
[ "$(log | grep -c 'okaeri: dry: hook')" = 0 ] || fail "a command as it's set: $(log | grep 'dry: hook' | tail -n 1)"

# The charger out and in, and a battery that gets low.
ipc probe battery 80 true
once_more battery 0
ipc probe battery 80 false
once_more charger 0
[ "$(ran low)" = 0 ] || fail "a battery that isn't low ran the command for one"
ipc probe battery 10 true
once_more low 0
once_more battery 1
ipc probe battery 100 false
once_more charger 1

# Another palette is one change, however many colors it has.
before=$(ran colors)
printf '{ "extends": "nord" }\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
once_more colors "$before"
sleep 0.6
[ "$(ran colors)" = $((before + 1)) ] || fail "a palette ran the colors' command $(($(ran colors) - before)) times"

# And another wallpaper.
settings "{ \"hooks\": { \"wallpaper\": \"true\" }, \"wallpaper\": { \"path\": \"$work/a.png\" } }"
once_more wallpaper 0

# Until the file $1 has the line $2, or fails after 5 s.
has() {
	for _ in $(seq 50); do
		grep -qxF -- "$2" "$1" 2>/dev/null && return 0
		sleep 0.1
	done
	fail "no \"$2\" in ${1##*/}, which has: $(cat "$1" 2>/dev/null || echo nothing)"
}

# The colors into other apps' files. One in the shell's own folder is written,
# in a folder that isn't there yet; one elsewhere only would be, as that's a
# change to the machine; and each that comes with the shell goes by its name.
cat >"$work/colors.tpl" <<'TPL'
bg={{background}} fg={{text.strip}} red={{error.rgb}} {{mode}} {{nothing}} {{text.other}}
TPL
written=$XDG_STATE_HOME/okaeri/test/colors.conf
shipped=$XDG_STATE_HOME/okaeri/test/shipped
templates="{ \"from\": \"$work/colors.tpl\", \"to\": \"$written\" }, { \"from\": \"$work/colors.tpl\", \"to\": \"$work/elsewhere.conf\" }"
for template in "$work"/shell/templates/*; do
	templates="$templates, { \"from\": \"${template##*/}\", \"to\": \"$shipped/${template##*/}\" }"
done
settings "{ \"hooks\": { \"templates\": [$templates] } }"
# Under nord, which is dark.
has "$written" 'bg=#2e3440 fg=eceff4 red=191, 97, 106 dark {{nothing}} {{text.other}}'
wait_log 'okaeri: dry: template 2'
[ ! -e "$work/elsewhere.conf" ] || fail "a file outside the shell's own was written in a dry run"
for template in "$work"/shell/templates/*; do
	for _ in $(seq 50); do
		[ -s "$shipped/${template##*/}" ] && break
		sleep 0.1
	done
	[ -s "$shipped/${template##*/}" ] || fail "nothing written of ${template##*/}"
	! grep -q '{{' "$shipped/${template##*/}" || fail "${template##*/} has what isn't a color: $(grep '{{' "$shipped/${template##*/}")"
done
has "$shipped/kitty.conf" 'background #2e3440'

# A light palette: the files follow, once its colors have all come.
printf '{ "extends": "catppuccin-latte" }\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
has "$written" 'bg=#eff1f5 fg=4c4f69 red=210, 15, 57 light {{nothing}} {{text.other}}'
has "$shipped/foot.ini" 'background=eff1f5'

# A color a template doesn't have leaves its file as it was, not written again.
before=$(stat -c %y "$written")
printf '{ "extends": "catppuccin-latte", "colors": { "accent": "#123456" } }\n' >"$XDG_CONFIG_HOME/okaeri/theme.json"
has "$shipped/kitty.conf" 'cursor #123456'
[ "$(stat -c %y "$written")" = "$before" ] || fail "a file was written again with nothing new in it"

# A template that changes is written again.
printf 'mode={{mode}}\n' >"$work/colors.tpl"
has "$written" 'mode=light'

# At a start a file that isn't as its template has it is written anew, and one
# that is stays as it was.
printf 'by hand\n' >"$written"
before=$(stat -c %y "$shipped/kitty.conf")
reloads=$(log | grep -c 'Reloading configuration' || true)
echo >>"$work/shell/hooks/Templates.qml"
for _ in $(seq 50); do
	[ "$(log | grep -c 'Reloading configuration' || true)" -gt "$reloads" ] && break
	sleep 0.1
done
[ "$(log | grep -c 'Reloading configuration' || true)" -gt "$reloads" ] || fail "the shell didn't reload"
has "$written" 'mode=light'
[ "$(stat -c %y "$shipped/kitty.conf")" = "$before" ] || fail "a start wrote a file that was as it should be"

echo "hooks: all good" >&2
