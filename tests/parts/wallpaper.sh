# The wallpaper, from settings, on a screen where nothing else covers it.

fail() {
	echo "wallpaper: $1" >&2
	exit 1
}

layers() {
	niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-wallpaper" and .layer == "Background")] | length'
}
wait_layers() {
	for _ in $(seq 40); do
		[ "$(layers)" = "$1" ] && return 0
		sleep 0.1
	done
	fail "$2: $(layers) up, not $1"
}
pixel() {
	magick "$out/$1.png" -format "%[hex:u.p{$2,$3}]" info: | cut -c1-6
}
settings() {
	printf '{ "wallpaper": { "path": "%s", "fade": 200 } }\n' "$1" >"$XDG_CONFIG_HOME/okaeri/settings.json"
}
# Until the screen at the middle is color $2, or fails saying $1.
wait_color() {
	for _ in $(seq 30); do
		shot color
		[ "$(pixel color 700 600)" = "$2" ] && return 0
		sleep 0.1
	done
	fail "$1: it's $(pixel color 700 600), not $2"
}

magick -size 1600x1200 xc:'#336699' "$work/blue.png"
magick -size 1600x1200 xc:'#996633' "$work/brown.png"
# A name that needs care in a URL.
cp "$work/brown.png" "$work/brown #1?.png"

# None by default.
sleep 0.5
[ "$(layers)" = 0 ] || fail "a wallpaper without a path"

settings "$work/blue.png"
wait_layers 1 "with a path"
wait_color "the first picture" 336699

# A new one takes over.
settings "$work/brown.png"
wait_color "the second picture" 996633
settings "$work/blue.png"
wait_color "back to the first" 336699
settings "$work/brown #1?.png"
wait_color "a name with # and ?" 996633

# Blurred behind the overview, and out of the way on the desktop. Half and half,
# for an edge that blurs.
magick -size 800x1200 xc:black -size 800x1200 xc:white +append "$work/half.png"
printf 'layer-rule {\n\tmatch namespace="^okaeri-backdrop$"\n\tplace-within-backdrop true\n}\nlayout {\n\tbackground-color "transparent"\n}\noverview {\n\tworkspace-shadow {\n\t\toff\n\t}\n}\n' >>"$work/niri.kdl"
sleep 0.5
printf '{ "wallpaper": { "path": "%s", "fade": 200, "backdrop": true } }\n' "$work/half.png" >"$XDG_CONFIG_HOME/okaeri/settings.json"
for _ in $(seq 30); do
	[ "$(niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-backdrop")] | length')" = 1 ] && break
	sleep 0.1
done
[ "$(niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-backdrop")] | length')" = 1 ] || fail "no backdrop"
sleep 1
shot desktop
# On the desktop the edge is sharp: a pixel either side of it is black and white.
[ "$(pixel desktop 697 600)" = 000000 ] || fail "the desktop isn't the picture: $(pixel desktop 697 600)"
[ "$(pixel desktop 703 600)" = FFFFFF ] || fail "the desktop isn't the picture: $(pixel desktop 703 600)"
niri msg action toggle-overview
sleep 1
shot overview
niri msg action toggle-overview
sleep 0.6


# Gone again.
settings ""
wait_layers 0 "without a path"

echo "wallpaper: all good" >&2
