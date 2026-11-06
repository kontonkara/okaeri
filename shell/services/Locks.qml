pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether CapsLock and NumLock are on, from the keyboards' lights: the compositor
// keeps those right and says nothing of them otherwise. A light doesn't tell of a
// change, so they're read a few times a second. Without one, `ready` is false.
Singleton {
	id: locks

	readonly property alias caps: capsLight.on
	readonly property alias num: numLight.on
	readonly property string device: capsLight.device + numLight.device
	readonly property bool ready: device !== ""

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

	Timer {
		interval: 200
		repeat: true
		running: locks.ready
		onTriggered: {
			capsLight.reload();
			numLight.reload();
		}
	}
}
