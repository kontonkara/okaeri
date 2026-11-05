#!/bin/sh
# Runs a command with what the tests need in PATH, from ~/nixos's nixpkgs.
exec nix shell --inputs-from "$HOME/nixos" \
	nixpkgs#quickshell nixpkgs#sway nixpkgs#grim nixpkgs#wlrctl nixpkgs#wtype \
	nixpkgs#libnotify nixpkgs#wl-clipboard nixpkgs#cliphist nixpkgs#dbus \
	nixpkgs#jq nixpkgs#imagemagick nixpkgs#kitty nixpkgs#util-linux nixpkgs#libqalculate -c "$@"
