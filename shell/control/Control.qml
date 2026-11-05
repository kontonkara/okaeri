pragma Singleton

import QtQuick
import Quickshell

// What the panel and its bar button share. Nothing here reaches for Wi-Fi or
// Bluetooth, so the bar doesn't start them: they come with the first opening.
Singleton {
	// The panel sets this.
	property bool open: false
	// The section that's unfolded, by its name.
	property string unfolded: "wifi"

	signal toggled

	function toggle() {
		toggled();
	}
}
