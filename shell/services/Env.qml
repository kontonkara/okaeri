pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How okaeri is running.
Singleton {
	// Tests: what would change the machine is only logged (see act()).
	readonly property bool dry: Quickshell.env("OKAERI_DRY") === "1"
	// Next to another shell (./try): what only one can hold stays off, the
	// notification server and the polkit agent.
	readonly property bool guest: Quickshell.env("OKAERI_GUEST") === "1"
	// Which of the tools some part of it runs aren't on this machine: that part
	// says so, in place of doing nothing.
	property var missing: []

	function lacks(tool) {
		return missing.includes(tool);
	}

	// Every change to the machine goes through here: volume, brightness,
	// Wi-Fi, Bluetooth, power, and what `what` says it is.
	function act(what, action) {
		if (dry)
			console.info(`okaeri: dry: ${what}`);
		else
			action();
	}

	Process {
		running: true
		command: ["sh", "-c", "for tool in cliphist wl-copy wl-paste wtype qalc; do command -v $tool >/dev/null 2>&1 || echo $tool; done"]
		stdout: StdioCollector {
			onStreamFinished: missing = text.split("\n").filter(tool => tool !== "")
		}
	}
}
