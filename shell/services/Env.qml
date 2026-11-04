pragma Singleton

import QtQuick
import Quickshell

// How okaeri is running.
Singleton {
	// Tests: what would change the machine is only logged (see act()).
	readonly property bool dry: Quickshell.env("OKAERI_DRY") === "1"
	// Next to another shell (./try): what only one can hold stays off, the
	// notification server and the polkit agent.
	readonly property bool guest: Quickshell.env("OKAERI_GUEST") === "1"

	// Every change to the machine goes through here: volume, brightness,
	// Wi-Fi, Bluetooth, power, and what `what` says it is.
	function act(what, action) {
		if (dry)
			console.info(`okaeri: dry: ${what}`);
		else
			action();
	}
}
