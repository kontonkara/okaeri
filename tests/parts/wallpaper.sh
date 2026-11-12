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

# The other ways a new one comes each get it there.
for way in slide wipe zoom; do
	printf '{ "wallpaper": { "path": "%s", "fade": 200, "transition": "%s" } }\n' "$work/blue.png" "$way" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	wait_color "the picture that comes by a $way" 336699
	printf '{ "wallpaper": { "path": "%s", "fade": 200, "transition": "%s" } }\n' "$work/brown.png" "$way" >"$XDG_CONFIG_HOME/okaeri/settings.json"
	wait_color "the next picture that comes by a $way" 996633
done

# One of another shape fills the screen, cut at its sides, or is whole, with the
# theme's black beside it.
magick -size 600x1200 xc:'#339966' "$work/tall.png"
settings "$work/tall.png"
wait_color "the tall picture" 339966
shot tall-cropped
[ "$(pixel tall-cropped 20 450)" = 339966 ] || fail "a cropped picture leaves the side: $(pixel tall-cropped 20 450)"
printf '{ "wallpaper": { "path": "%s", "fade": 200, "fill": "fit" } }\n' "$work/tall.png" >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.8
shot tall-fitted
[ "$(pixel tall-fitted 700 450)" = 339966 ] || fail "a fitted picture isn't in the middle: $(pixel tall-fitted 700 450)"
[ "$(pixel tall-fitted 20 450)" = 000000 ] || fail "a fitted picture is at the side too: $(pixel tall-fitted 20 450)"

# A screen's own picture is that screen's, and the rest have everyone's.
output=$(niri msg --json outputs | jq -r 'keys[0]')
printf '{ "wallpaper": { "path": "%s", "fade": 200, "screens": { "%s": "%s" } } }\n' "$work/blue.png" "$output" "$work/brown.png" >"$XDG_CONFIG_HOME/okaeri/settings.json"
wait_color "the screen's own picture" 996633
printf '{ "wallpaper": { "path": "%s", "fade": 200, "screens": { "another": "%s" } } }\n' "$work/blue.png" "$work/brown.png" >"$XDG_CONFIG_HOME/okaeri/settings.json"
wait_color "everyone's picture" 336699

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


# Another of the folder's by a call: the next by name, round to the first again,
# the one before, and any other. That's kept over the config, so it's last here.
mkdir "$work/pictures"
magick -size 1600x1200 xc:'#336699' "$work/pictures/a.png"
magick -size 1600x1200 xc:'#996633' "$work/pictures/b.png"
magick -size 1600x1200 xc:'#339966' "$work/pictures/c.png"
printf '{ "wallpaper": { "path": "%s", "folder": "%s", "fade": 200 } }\n' "$work/pictures/a.png" "$work/pictures" >"$XDG_CONFIG_HOME/okaeri/settings.json"
wait_color "the first of a folder" 336699
ipc wallpaper next
wait_color "the next of the folder" 996633
ipc wallpaper next
wait_color "the last of the folder" 339966
ipc wallpaper next
wait_color "round to the first" 336699
ipc wallpaper previous
wait_color "the one before the first" 339966
ipc wallpaper random
for _ in $(seq 30); do
	shot color
	[ "$(pixel color 700 600)" != 339966 ] && break
	sleep 0.1
done
[ "$(pixel color 700 600)" != 339966 ] || fail "any other of the folder is the same one"

# By itself with `every`, and not before its time: that's counted from the last
# one, kept in a file, so a day's picture comes on a machine that was off too.
sleep 0.6
shot settled
last=$(pixel settled 700 600)
printf '{ "wallpaper": { "path": "%s", "folder": "%s", "fade": 200, "every": 60 } }\n' "$work/pictures/a.png" "$work/pictures" >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 1.5
shot early
[ "$(pixel early 700 600)" = "$last" ] || fail "another picture before its time"
# The shell starts two hours after the last one, as on a machine that was off.
kill "$qs_pid"
wait "$qs_pid" 2>/dev/null || true
echo "$((($(date +%s) - 7200) * 1000))" >"$XDG_STATE_HOME/okaeri/wallpaper-turned"
quickshell -p "$work/shell" >>"$out/qs.log" 2>&1 &
qs_pid=$!
sleep 2
for _ in $(seq 40); do
	shot color
	[ "$(pixel color 700 600)" != "$last" ] && break
	sleep 0.1
done
[ "$(pixel color 700 600)" != "$last" ] || fail "no other picture two hours after the last, with one an hour"
sleep 0.6
shot turned
case $(pixel turned 700 600) in
336699 | 996633 | 339966) ;;
*) fail "what came two hours after the last isn't a picture of the folder: $(pixel turned 700 600)" ;;
esac

echo "wallpaper: all good" >&2
