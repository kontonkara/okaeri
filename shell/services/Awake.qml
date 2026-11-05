pragma Singleton

import QtQuick
import Quickshell

// Keeping the machine awake: while it's on, idling does nothing.
Singleton {
	property alias on: kept.on

	function toggle() {
		on = !on;
	}

	// What a reload leaves as it was.
	PersistentProperties {
		id: kept

		property bool on: false

		reloadableId: "awake"
	}
}
