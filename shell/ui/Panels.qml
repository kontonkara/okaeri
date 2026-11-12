pragma Singleton

import QtQuick
import Quickshell
import qs

// What the panels tell each other.
Singleton {
	// What's open.
	property var open: []

	// `panel` came up: what's in the same place makes way for it.
	signal opened(var panel)

	// Where along the bar `item` has its middle: across its screen, or down it for
	// a bar at a side.
	function middleOf(item) {
		const margins = item.QsWindow.window.margins;
		if (Settings.barSide)
			return item.mapToItem(null, 0, item.height / 2).y + (margins?.top ?? 0);
		return item.mapToItem(null, item.width / 2, 0).x + (margins?.left ?? 0);
	}
}
