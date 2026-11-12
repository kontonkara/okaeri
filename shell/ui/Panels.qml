pragma Singleton

import QtQuick
import Quickshell
import qs

// What the panels tell each other.
Singleton {
	// What's open.
	property var open: []

	// `panel` came up: what else is open makes way for it.
	signal opened(var panel)
	// A key wants the panel of a part of a bar, by the part's name: the one on
	// `screen`, or with "" any one. The first that takes it says so in `answered`.
	signal partWanted(string name, string screen)
	property bool answered: false
	// A click on the bar where nothing is: what's open goes, as for one elsewhere.
	signal away

	// The panel of part `name` on the bar of screen `focused`, or if that bar has
	// none, of the first bar that has one.
	function ask(name, focused) {
		answered = false;
		partWanted(name, focused);
		if (!answered)
			partWanted(name, "");
		if (!answered)
			console.info(`okaeri: no ${name} on a bar to open`);
	}

	// Where along the bar `item` has its middle: across its screen, or down it for
	// a bar at a side.
	function middleOf(item) {
		const margins = item.QsWindow.window.margins;
		if (Settings.barSide)
			return item.mapToItem(null, 0, item.height / 2).y + (margins?.top ?? 0);
		return item.mapToItem(null, item.width / 2, 0).x + (margins?.left ?? 0);
	}
}
