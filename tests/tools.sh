#!/bin/sh
# Runs a command with what the tests need in PATH, from ~/nixos's nixpkgs, and
# mpv's MPRIS plugin, which isn't a program, at $OKAERI_MPV_MPRIS.
OKAERI_MPV_MPRIS=$(nix build --no-link --print-out-paths --inputs-from "$HOME/nixos" nixpkgs#mpvScripts.mpris)/share/mpv/scripts/mpris.so
export OKAERI_MPV_MPRIS
exec nix shell --inputs-from "$HOME/nixos" \
	nixpkgs#quickshell nixpkgs#sway nixpkgs#grim nixpkgs#wlrctl nixpkgs#wtype \
	nixpkgs#libnotify nixpkgs#wl-clipboard nixpkgs#cliphist nixpkgs#dbus \
	nixpkgs#jq nixpkgs#imagemagick nixpkgs#kitty nixpkgs#util-linux nixpkgs#mpv nixpkgs#libqalculate -c "$@"
