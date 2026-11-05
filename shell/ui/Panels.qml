pragma Singleton

import QtQuick
import Quickshell

// What the panels tell each other.
Singleton {
	// What's open.
	property var open: []

	// `panel` came up: what's in the same place makes way for it.
	signal opened(var panel)

	// Where across its screen `item` has its middle.
	function middleOf(item) {
		return item.mapToItem(null, item.width / 2, 0).x + (item.QsWindow.window.margins?.left ?? 0);
	}
}
