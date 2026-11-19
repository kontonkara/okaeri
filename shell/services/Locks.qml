pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Whether CapsLock and NumLock are on, from the keyboards' lights: the compositor
// keeps those right and says nothing of them otherwise. A light doesn't tell of a
// change, so they're read a few times a second, though only while something shows
// them and only while there's input: a key is what changes them. Without one,
// `ready` is false, and the lights are looked for again now and then.
Singleton {
	id: locks

	readonly property alias caps: capsLight.on
	readonly property alias num: numLight.on
	readonly property string device: capsLight.device + numLight.device
	readonly property bool ready: device !== ""
	// What shows them, besides the OSD where it doesn't leave them out: the bar's
	// part and the password dialog count themselves in here.
	property int users: 0
	readonly property bool wanted: users > 0 || !Settings.osd.hidden.includes("locks")

	function look() {
		capsLight.reload();
		numLight.reload();
	}

	component Light: FileView {
		property string device
		property bool on: false

		path: device ? `/sys/class/leds/${device}/brightness` : ""
		printErrors: false
		onLoaded: on = Number(text()) > 0
		// A keyboard that's gone: there may be another.
		onLoadFailed: finder.running = true
	}

	Light {
		id: capsLight
	}

	Light {
		id: numLight
	}

	Process {
		id: finder

		running: true
		command: ["ls", "/sys/class/leds"]

		stdout: StdioCollector {
			onStreamFinished: {
				const names = text.split("\n");
				capsLight.device = names.find(name => name.endsWith("::capslock")) ?? "";
				numLight.device = names.find(name => name.endsWith("::numlock")) ?? "";
			}
		}
	}

	// Input in the last two seconds, whatever holds the machine awake: another
	// program can turn a lock on too, but it's a key nearly always. Once more as it
	// goes still, for the last of it.
	IdleMonitor {
		id: still

		timeout: 2
		respectInhibitors: false
		onIsIdleChanged: {
			if (isIdle && locks.ready)
				locks.look();
		}
	}

	Timer {
		interval: 200
		repeat: true
		running: locks.ready && locks.wanted && !still.isIdle
		onTriggered: locks.look()
	}

	// A keyboard plugged in later.
	Timer {
		interval: 30000
		repeat: true
		running: !locks.ready && locks.wanted
		onTriggered: finder.running = true
	}
}
