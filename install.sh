#!/bin/sh
# Puts okaeri in your home and into niri's config, or takes it all away again:
#
#   curl -fsSL https://raw.githubusercontent.com/kontonkara/okaeri/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/kontonkara/okaeri/main/install.sh | sh -s uninstall
#
# or from a clone, `./install.sh` and `./install.sh uninstall`; installed, it's
# also at ~/.local/share/okaeri/install.sh. Running it again updates it.
#
# It installs into ~/.local/share/okaeri, links ~/.local/bin/okaeri to it, and
# puts two includes at the top of niri's config.kdl, between "okaeri" marks:
# its own file, with the shell's start and its keys, and the one the shell keeps.
# Keys you bound yourself come later in your config and win. What the shell needs
# from the system it asks your package manager for, if you say so. Uninstalling
# stops the shell and takes the marks and all between them away, the files, and,
# if you say so, your settings. It never needs root but for packages.
#
# OKAERI_REF is the branch or tag it downloads, main by default.
set -eu

ref=${OKAERI_REF:-main}
archive="https://github.com/kontonkara/okaeri/archive/$ref.tar.gz"
data=${XDG_DATA_HOME:-$HOME/.local/share}
dest=$data/okaeri
link=$HOME/.local/bin/okaeri
niri_dir=${XDG_CONFIG_HOME:-$HOME/.config}/niri
niri_config=$niri_dir/config.kdl
settings=${XDG_CONFIG_HOME:-$HOME/.config}/okaeri
state=${XDG_STATE_HOME:-$HOME/.local/state}/okaeri
begin="// okaeri: begin, install.sh puts this here and takes it away"
end="// okaeri: end"
# Before a line of niri's config that install.sh turned off.
off="// okaeri turned this off: "
# Bars and shells niri may start that would show beside it.
others="waybar|ironbar|eww|ags|astal|hyprpanel|nwg-panel|yambar|sfwbar|qs|quickshell|noctalia-shell|dms|caelestia"

say() {
	printf '%s\n' "$*"
}
fail() {
	say "okaeri: $*" >&2
	exit 1
}
has() {
	command -v "$1" >/dev/null 2>&1
}
# A yes or no from whoever runs it, $2 by default: piped into sh, the terminal
# is still there. With none, nobody said yes.
ask() {
	{ true </dev/tty; } 2>/dev/null || return 1
	if [ "$2" = yes ]; then
		printf '%s [Y/n] ' "$1" >/dev/tty
	else
		printf '%s [y/N] ' "$1" >/dev/tty
	fi
	read -r answer </dev/tty || answer=
	case $answer in
	[Yy]*) return 0 ;;
	[Nn]*) return 1 ;;
	*) [ "$2" = yes ] ;;
	esac
}

# What a command needs installed, and the package that has it here.
distro() {
	release=${OKAERI_OS_RELEASE:-/etc/os-release}
	[ -r "$release" ] || {
		echo unknown
		return
	}
	# shellcheck source=/dev/null
	ids=$(. "$release" && echo "${ID:-} ${ID_LIKE:-}")
	case " $ids " in
	*" nixos "*) echo nixos ;;
	*" arch "*) echo arch ;;
	*" fedora "*) echo fedora ;;
	*" opensuse"*|*" suse "*) echo opensuse ;;
	*" void "*) echo void ;;
	*" debian "*|*" ubuntu "*) echo debian ;;
	*) echo unknown ;;
	esac
}
package() {
	case $1 in
	quickshell) echo quickshell ;;
	niri) echo niri ;;
	cliphist) echo cliphist ;;
	qalc)
		case $2 in
		arch|void) echo libqalculate ;;
		debian) echo qalc ;;
		*) echo qalculate ;;
		esac
		;;
	wl-copy) echo wl-clipboard ;;
	wtype) echo wtype ;;
	notify-send)
		case $2 in
		debian) echo libnotify-bin ;;
		opensuse) echo libnotify-tools ;;
		*) echo libnotify ;;
		esac
		;;
	pw-play)
		case $2 in
		debian) echo pipewire-bin ;;
		fedora) echo pipewire-utils ;;
		opensuse) echo pipewire-tools ;;
		*) echo pipewire ;;
		esac
		;;
	wlsunset) echo wlsunset ;;
	sounds) echo sound-theme-freedesktop ;;
	esac
}
install_command() {
	case $1 in
	arch) echo "sudo pacman -S --needed" ;;
	fedora) echo "sudo dnf install" ;;
	opensuse) echo "sudo zypper install" ;;
	void) echo "sudo xbps-install" ;;
	debian) echo "sudo apt install" ;;
	esac
}
# Where Quickshell 0.3 or niri 26.04 isn't packaged yet.
unpackaged() {
	case "$1 $2" in
	"fedora quickshell"|"opensuse quickshell"|"debian quickshell") return 0 ;;
	"debian niri") return 0 ;;
	esac
	return 1
}

sounds_there() {
	for dir in ${XDG_DATA_HOME:-$HOME/.local/share} $(echo "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' ' '); do
		[ -d "$dir/sounds/freedesktop" ] && return 0
	done
	return 1
}
missing() {
	for command in quickshell niri cliphist qalc wl-copy wtype notify-send pw-play wlsunset; do
		has "$command" || echo "$command"
	done
	sounds_there || echo sounds
}
# Quickshell's version as a number to compare: 0.3.2 is 302.
quickshell_version() {
	quickshell --version 2>/dev/null | sed -n 's/^Quickshell \([0-9]*\)\.\([0-9]*\).*/\1 \2/p' | {
		read -r major minor || exit 0
		echo $((major * 100 + minor))
	}
}
niri_version() {
	niri --version 2>/dev/null | sed -n 's/^niri \([0-9]*\)\.\([0-9]*\).*/\1\2/p'
}

packages() {
	lacking=$(missing)
	[ -n "$lacking" ] || return 0
	os=$(distro)
	say "Not there yet: $(echo "$lacking" | tr '\n' ' ')"
	if [ "$os" = nixos ]; then
		say "On NixOS the flake's package and Home Manager module bring it all: see nix/ in the repository."
		return 0
	fi
	if [ "$os" = unknown ]; then
		say "Install those with your package manager: the sound theme is sound-theme-freedesktop."
		return 0
	fi
	names=
	for command in $lacking; do
		if unpackaged "$os" "$command"; then
			case $command in
			quickshell) say "Quickshell 0.3 isn't packaged for this system yet: https://quickshell.org has how to build it." ;;
			niri) say "niri 26.04 isn't packaged for this system yet: https://github.com/niri-wm/niri has how to get it." ;;
			esac
		else
			names="$names $(package "$command" "$os")"
		fi
	done
	[ -n "$names" ] || return 0
	command="$(install_command "$os")$names"
	if ask "Install them with: $command ?" yes; then
		# shellcheck disable=SC2086
		$command || say "That didn't go through: okaeri can still run, with less."
	else
		say "Later, with: $command"
	fi
}

# The tree to install, in $tree: this clone, or a download of $ref, also when
# it's the installed copy that runs.
find_tree() {
	here=$(cd "$(dirname "$0")" && pwd)
	if [ "$here" != "$dest" ] && [ -f "$here/shell/shell.qml" ] && [ -f "$here/bin/okaeri" ]; then
		tree=$here
		return
	fi
	download=$(mktemp -d)
	trap 'rm -rf "$download"' EXIT
	if [ -n "${OKAERI_ARCHIVE:-}" ]; then
		cp "$OKAERI_ARCHIVE" "$download/okaeri.tar.gz"
	elif has curl; then
		curl -fsSL "$archive" -o "$download/okaeri.tar.gz" || fail "couldn't download $archive"
	elif has wget; then
		wget -q -O "$download/okaeri.tar.gz" "$archive" || fail "couldn't download $archive"
	else
		fail "neither curl nor wget is there to download it"
	fi
	tar -xzf "$download/okaeri.tar.gz" -C "$download" || fail "the download isn't an archive"
	found=$(find "$download" -mindepth 2 -maxdepth 3 -path '*/shell/shell.qml' | head -n 1)
	[ -n "$found" ] || fail "no shell in the download"
	tree=$(dirname "$(dirname "$found")")
}

# niri's config without the marks and what's between them, and the blank line
# after the end mark, which was put there with them.
unmarked() {
	awk -v begin="$begin" -v end="$end" -v off="$off" '
		index($0, off) == 1 { $0 = substr($0, length(off) + 1) }
		$0 == begin { skipping = 1; next }
		skipping && $0 == end { skipping = 0; dropping = 1; next }
		skipping { next }
		dropping && $0 == "" { dropping = 0; next }
		{ dropping = 0; print }
	' "$niri_config"
}

niri_file() {
	okaeri=$dest/bin/okaeri
	cat <<KDL
// okaeri's start and its keys, from install.sh, which writes this anew on each
// run. niri's config.kdl includes it before what's yours: a key bound there wins.

spawn-at-startup "$okaeri"

binds {
    Mod+Space hotkey-overlay-title="Launcher" { spawn "$okaeri" "launcher" "toggle"; }
    Mod+Alt+V hotkey-overlay-title="Clipboard" { spawn "$okaeri" "clipboard" "toggle"; }
    Mod+Shift+Escape hotkey-overlay-title="Session menu" { spawn "$okaeri" "session" "toggle"; }
    Mod+Shift+Comma hotkey-overlay-title="Settings" { spawn "$okaeri" "settings" "toggle"; }
    XF86AudioRaiseVolume allow-when-locked=true { spawn "$okaeri" "volume" "up" "5"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "$okaeri" "volume" "down" "5"; }
    XF86AudioMute allow-when-locked=true { spawn "$okaeri" "volume" "mute"; }
    XF86AudioMicMute allow-when-locked=true { spawn "$okaeri" "mic" "mute"; }
    XF86MonBrightnessUp allow-when-locked=true { spawn "$okaeri" "brightness" "up" "5"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "$okaeri" "brightness" "down" "5"; }
    XF86AudioPlay allow-when-locked=true { spawn "$okaeri" "media" "toggle"; }
    XF86AudioNext allow-when-locked=true { spawn "$okaeri" "media" "next"; }
    XF86AudioPrev allow-when-locked=true { spawn "$okaeri" "media" "previous"; }
}
KDL
}

# The marks at the top of niri's config, written in place: niri reads it anew
# as it changes.
mark_niri() {
	if [ ! -f "$niri_config" ]; then
		say "niri has no config yet: start niri once, then run this again for its start and keys."
		return
	fi
	if grep -qxF "$begin" "$niri_config"; then
		return
	fi
	[ -e "$niri_config.before-okaeri" ] || cp "$niri_config" "$niri_config.before-okaeri"
	{
		say "$begin"
		say "include optional=true \"$dest/niri.kdl\""
		say "include optional=true \"$state/niri.kdl\""
		say "$end"
		say ""
		cat "$niri_config"
	} >"$niri_config.okaeri-new"
	cat "$niri_config.okaeri-new" >"$niri_config"
	rm "$niri_config.okaeri-new"
	say "niri's config includes okaeri now: $niri_config (as it was: $niri_config.before-okaeri)"
	turn_off_others
}

# Another bar that niri starts, off by a mark, if you say so.
turn_off_others() {
	lines=$(grep -nE "^[[:space:]]*spawn-at-startup[[:space:]]+\"($others)\"" "$niri_config" | cut -d: -f1 || true)
	[ -n "$lines" ] || return 0
	say "niri starts another bar as well:"
	for line in $lines; do
		say "  $(sed -n "${line}p" "$niri_config")"
	done
	ask "Turn that off, till okaeri goes?" yes || {
		say "It stays, beside okaeri."
		return 0
	}
	for line in $lines; do
		sed "${line}s|^|$off|" "$niri_config" >"$niri_config.okaeri-new"
		cat "$niri_config.okaeri-new" >"$niri_config"
	done
	rm -f "$niri_config.okaeri-new"
}

unmark_niri() {
	[ -f "$niri_config" ] && grep -qxF "$begin" "$niri_config" || return 0
	unmarked >"$niri_config.okaeri-new"
	cat "$niri_config.okaeri-new" >"$niri_config"
	rm "$niri_config.okaeri-new"
	say "niri's config is without okaeri again."
}

install_okaeri() {
	packages
	has quickshell || fail "it needs Quickshell 0.3 or newer: https://quickshell.org"
	version=$(quickshell_version)
	[ "${version:-0}" -ge 3 ] || fail "it needs Quickshell 0.3 or newer, and this one says: $(quickshell --version 2>&1 | head -n 1)"
	if ! has niri; then
		say "niri isn't here: okaeri is for niri 26.04 or newer."
	elif [ "$(niri_version)" -lt 2604 ] 2>/dev/null; then
		say "This niri is older than 26.04: some of okaeri won't work on it."
	fi

	find_tree
	# What's there is replaced only if it's an install of ours.
	if [ -e "$dest" ] && [ ! -f "$dest/.okaeri-install" ]; then
		fail "$dest is there and isn't from install.sh: move it away first"
	fi
	staging=$data/.okaeri-new
	rm -rf "$staging"
	mkdir -p "$staging"
	cp -R "$tree/shell" "$tree/bin" "$staging/"
	cp "$tree/install.sh" "$tree/license" "$tree/readme.md" "$staging/" 2>/dev/null || true
	echo "$ref" >"$staging/.okaeri-install"
	rm -rf "$dest"
	mv "$staging" "$dest"
	chmod +x "$dest/bin/okaeri" "$dest/install.sh" 2>/dev/null || true
	niri_file >"$dest/niri.kdl"

	mkdir -p "$(dirname "$link")"
	if [ -L "$link" ] || [ ! -e "$link" ]; then
		ln -sfn "$dest/bin/okaeri" "$link"
	else
		say "$link is there and isn't a link: okaeri is at $dest/bin/okaeri"
	fi
	mark_niri

	say "okaeri is installed in $dest."
	if [ -n "${NIRI_SOCKET:-}" ] && has niri && ask "Start it now? Another bar that's running stays, until it's stopped." yes; then
		niri msg action spawn -- "$dest/bin/okaeri" >/dev/null && say "It's starting."
	else
		say "It starts with niri; $dest/bin/okaeri starts it now."
	fi
	say "To take it away: $dest/install.sh uninstall"
}

uninstall_okaeri() {
	if [ -d "$dest/shell" ] && has quickshell; then
		quickshell kill -p "$dest/shell" >/dev/null 2>&1 || true
	fi
	unmark_niri
	if [ -L "$link" ] && [ "$(readlink "$link")" = "$dest/bin/okaeri" ]; then
		rm "$link"
	fi
	if [ -f "$dest/.okaeri-install" ]; then
		rm -rf "$dest"
	elif [ -e "$dest" ]; then
		say "$dest isn't from install.sh: it stays."
	fi
	rm -rf "$state"
	if [ -d "$settings" ]; then
		if ask "Your settings too, $settings?" no; then
			rm -rf "$settings"
		else
			say "Your settings stay in $settings."
		fi
	fi
	[ ! -e "$niri_config.before-okaeri" ] || rm "$niri_config.before-okaeri"
	say "okaeri is gone. What it asked the package manager for stays: other things may use it."
}

case ${1:-install} in
install) install_okaeri ;;
uninstall) uninstall_okaeri ;;
*) fail "usage: install.sh [install|uninstall]" ;;
esac
