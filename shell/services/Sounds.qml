pragma Singleton

import QtQuick
import Quickshell
import qs

// Short sounds out of the freedesktop sound theme, wherever that's installed, at
// Settings.sounds.volume. Several at once make one.
Singleton {
	id: sounds

	readonly property string player: `IFS=:
for dir in \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
	for kind in oga ogg wav; do
		file=$dir/sounds/freedesktop/stereo/$2.$kind
		[ -f "$file" ] && exec pw-play --media-role Notification --volume "$1" "$file"
	done
done`
	property double last: 0

	function play(name) {
		if (Settings.sounds.volume > 0 && Date.now() - last > 100) {
			last = Date.now();
			Env.act(`sound ${name}`, () => Quickshell.execDetached(["sh", "-c", player, "sh", String(Settings.sounds.volume / 100), name]));
		}
	}
}
