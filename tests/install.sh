#!/bin/sh
# install.sh in a home of its own, with no terminal to answer: installed from
# the clone and from a download, run again, and taken away, niri's config
# coming out of that as it went in. Nothing of the real home is touched, and
# nothing runs as root: with no one to say yes it asks the package manager
# for nothing. In the repo:
#
#   tests/tools.sh tests/install.sh <out>
set -eu

out=$(mkdir -p "${1:?usage: install.sh <out>}" && cd "$1" && pwd)
repo=$PWD
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT

fail() {
	echo "install: $1" >&2
	exit 1
}
step() {
	echo "install: $1" >&2
}
same() {
	[ "$2" = "$3" ] || fail "$1: got \"$2\", not \"$3\""
}

# A config like niri's own first one: another bar, and keys of its own.
mkdir -p "$home/.config/niri"
cat >"$home/.config/niri/config.kdl" <<'KDL'
input {
    keyboard {
        xkb {
        }
    }
}

spawn-at-startup "waybar"

binds {
    Mod+T { spawn "alacritty"; }
    Mod+V { toggle-window-floating; }
}
KDL
cp "$home/.config/niri/config.kdl" "$out/config-before.kdl"

# The installer in that home, detached from any terminal, out of the real
# session. Its words go to <out>/<name>.log.
env=$(command -v env)
setsid=$(command -v setsid)
run() {
	name=$1
	shift
	"$env" -i HOME="$home" PATH="$PATH" XDG_DATA_DIRS="${XDG_DATA_DIRS:-}" OKAERI_OS_RELEASE="${OKAERI_OS_RELEASE:-/etc/os-release}" \
		${OKAERI_ARCHIVE:+OKAERI_ARCHIVE="$OKAERI_ARCHIVE"} "$setsid" -w "$@" >"$out/$name.log" 2>&1 </dev/null
}
dest=$home/.local/share/okaeri
config=$home/.config/niri/config.kdl
# What a download would bring: this tree.
git -C "$repo" ls-files -co --exclude-standard | tar -cf - -C "$repo" --transform 's|^|okaeri-main/|' -T - | gzip >"$out/okaeri.tar.gz"

step "From the clone"
run first sh "$repo/install.sh"
[ -f "$dest/shell/shell.qml" ] || fail "no shell in $dest"
[ -x "$dest/bin/okaeri" ] || fail "no okaeri in $dest"
[ -x "$dest/install.sh" ] || fail "no install.sh beside it, to take it away"
same "the link" "$(readlink "$home/.local/bin/okaeri")" "$dest/bin/okaeri"
same "the config's first line" "$(head -n 1 "$config")" "// okaeri: begin, install.sh puts this here and takes it away"
grep -qxF "include optional=true \"$dest/niri.kdl\"" "$config" || fail "no include of okaeri's keys"
grep -qxF "include optional=true \"$home/.local/state/okaeri/niri.kdl\"" "$config" || fail "no include of the shell's own file"
same "the rest of the config" "$(sed '1,/^\/\/ okaeri: end$/d' "$config" | sed '1d')" "$(cat "$out/config-before.kdl")"
grep -q "Mod+Space .*\"$dest/bin/okaeri\" \"launcher\" \"toggle\"" "$dest/niri.kdl" || fail "no key for the launcher"
grep -q "spawn-at-startup \"$dest/bin/okaeri\"" "$dest/niri.kdl" || fail "nothing starts it"
# With no one to say so, the other bar stays, and so does the system.
grep -qx 'spawn-at-startup "waybar"' "$config" || fail "the other bar was turned off unasked"
if command -v niri >/dev/null; then
	niri validate -c "$config" >"$out/validate.log" 2>&1 || fail "niri doesn't take the config: $(tail -n 3 "$out/validate.log")"
fi

step "Again, as an update"
echo "left behind" >"$dest/shell/stale.qml"
OKAERI_ARCHIVE="$out/okaeri.tar.gz" run again sh "$dest/install.sh"
same "the marks after a second run" "$(grep -c '^// okaeri: begin' "$config")" 1
[ ! -e "$dest/shell/stale.qml" ] || fail "an update left the old files"

step "Away again"
mkdir -p "$home/.local/state/okaeri" "$home/.config/okaeri"
echo '{}' >"$home/.local/state/okaeri/settings.json"
echo '{}' >"$home/.config/okaeri/settings.json"
run away sh "$dest/install.sh" uninstall
[ ! -e "$dest" ] || fail "$dest is still there"
[ ! -e "$home/.local/bin/okaeri" ] || fail "the link is still there"
[ ! -e "$home/.local/state/okaeri" ] || fail "the shell's state is still there"
[ -f "$home/.config/okaeri/settings.json" ] || fail "the settings went unasked"
cmp -s "$config" "$out/config-before.kdl" || fail "niri's config isn't as it was: $(diff "$out/config-before.kdl" "$config" | head -n 5)"
[ ! -e "$config.before-okaeri" ] || fail "the copy of the config is still there"

step "From a download"
cp "$repo/install.sh" "$home/install.sh"
(cd "$home" && OKAERI_ARCHIVE="$out/okaeri.tar.gz" run download sh -c 'sh < install.sh')
[ -f "$dest/shell/shell.qml" ] || fail "nothing came of the download: $(tail -n 3 "$out/download.log")"
cmp -s "$dest/install.sh" "$repo/install.sh" || fail "the download's install.sh isn't this one"
run away-again sh "$dest/install.sh" uninstall
cmp -s "$config" "$out/config-before.kdl" || fail "niri's config isn't as it was after the download"

step "With someone to answer"
# A terminal of its own, which says yes: the other bar goes off, and comes back
# with the rest of the config as it goes; the settings go too.
script=$(command -v script)
answered() {
	name=$1
	shift
	printf 'y\ny\ny\n' | "$env" -i HOME="$home" PATH="$PATH" TERM=dumb "$script" -qec "PATH='$PATH' $*" /dev/null >"$out/$name.log" 2>&1
}
answered asked sh "$repo/install.sh"
grep -qx '// okaeri turned this off: spawn-at-startup "waybar"' "$config" || fail "the other bar is still on: $(grep waybar "$config")"
niri validate -c "$config" >/dev/null 2>&1 || ! command -v niri >/dev/null || fail "niri doesn't take the config with the bar off"
mkdir -p "$home/.config/okaeri"
echo '{}' >"$home/.config/okaeri/settings.json"
answered asked-away sh "$dest/install.sh" uninstall
cmp -s "$config" "$out/config-before.kdl" || fail "niri's config isn't as it was after a yes: $(diff "$out/config-before.kdl" "$config" | head -n 5)"
[ ! -e "$home/.config/okaeri" ] || fail "the settings stayed after a yes"

step "What's missing, and how to get it"
# A PATH with only what install.sh itself uses, and Quickshell.
tools=$home/tools
mkdir -p "$tools"
for tool in sh awk sed grep cp mv rm mkdir ln cat readlink dirname find tar gzip mktemp tr cut head chmod env quickshell; do
	ln -s "$(command -v "$tool")" "$tools/$tool"
done
printf 'ID=cachyos\nID_LIKE=arch\n' >"$home/os-release"
PATH=$tools XDG_DATA_DIRS=$home/nothing OKAERI_OS_RELEASE=$home/os-release run arch "$tools/sh" "$repo/install.sh"
grep -qxF 'Later, with: sudo pacman -S --needed niri cliphist libqalculate wl-clipboard wtype libnotify pipewire wlsunset sound-theme-freedesktop' "$out/arch.log" ||
	fail "not the packages to get: $(grep -i 'with:' "$out/arch.log")"
printf 'ID=fedora\n' >"$home/os-release"
PATH=$tools XDG_DATA_DIRS=$home/nothing OKAERI_OS_RELEASE=$home/os-release run fedora "$tools/sh" "$repo/install.sh" uninstall
PATH=$tools XDG_DATA_DIRS=$home/nothing OKAERI_OS_RELEASE=$home/os-release run fedora "$tools/sh" "$repo/install.sh"
grep -qxF 'Later, with: sudo dnf install niri cliphist qalculate wl-clipboard wtype libnotify pipewire-utils wlsunset sound-theme-freedesktop' "$out/fedora.log" ||
	fail "not Fedora's packages: $(grep -i 'with:' "$out/fedora.log")"
PATH=$tools run last "$tools/sh" "$repo/install.sh" uninstall

echo "install: all good" >&2
