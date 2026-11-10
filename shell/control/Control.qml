pragma Singleton

import QtQuick
import Quickshell
import qs

// What the panel and its bar button share. Nothing here reaches for Wi-Fi or
// Bluetooth, so the bar doesn't start them: they come with the first opening.
Singleton {
	// The panel sets this.
	property bool open: false
	// The page that's open, by its name, and whether the keys opened it: the
	// keys then go on to it.
	property string unfolded: ""
	property bool keyed: false

	signal toggled

	// The tiles there are, by their names, in Settings.control.tiles' order, the
	// ones it doesn't name after it.
	readonly property var tiles: ["wifi", "bluetooth", "night", "awake", "power"]
	readonly property var order: Settings.control.tiles.filter(name => tiles.includes(name)).concat(tiles.filter(name => !Settings.control.tiles.includes(name)))

	function toggle() {
		toggled();
	}

	// Which of `names`, the tiles as they come, take a whole row: a wide one, and
	// one left alone in its row, before a wide one or at the end.
	function whole(names) {
		const result = {};
		let half = false;
		names.forEach((name, at) => {
			if (Settings.control.wide.includes(name)) {
				result[name] = true;
			} else if (half) {
				result[name] = false;
				half = false;
			} else {
				const next = names[at + 1];
				result[name] = next === undefined || Settings.control.wide.includes(next);
				half = !result[name];
			}
		});
		return result;
	}
}
