pragma Singleton

import QtQuick
import Quickshell

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

	function toggle() {
		toggled();
	}
}
