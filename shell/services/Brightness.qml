pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The first backlight's brightness, 0 to 1: read from sysfs, and set through
// logind, which lets the session's user do that.
Singleton {
	id: brightness

	property string device: ""
	readonly property string directory: device ? `/sys/class/backlight/${device}` : ""
	readonly property bool available: device !== "" && maximum > 0
	readonly property int maximum: Number(maximumFile.text()) || 0
	property int current: 0
	readonly property real level: available ? current / maximum : 0
	// Never dark enough to leave nothing to see by.
	readonly property real lowest: 0.01

	function change(by) {
		if (!available)
			return;
		const value = Math.round(Math.max(lowest, Math.min(1, level + by)) * maximum);
		Env.act(`brightness ${value}`, () => {
			// Shown at once; the file follows.
			current = value;
			setter.command = ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", device, String(value)];
			setter.running = true;
		});
	}

	Process {
		running: true
		command: ["ls", "/sys/class/backlight"]

		stdout: StdioCollector {
			onStreamFinished: brightness.device = text.split("\n")[0]
		}
	}

	Process {
		id: setter
	}

	FileView {
		id: maximumFile

		path: brightness.directory ? `${brightness.directory}/max_brightness` : ""
		blockLoading: true
		printErrors: false
	}

	FileView {
		path: brightness.directory ? `${brightness.directory}/actual_brightness` : ""
		blockLoading: true
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
		onLoaded: brightness.current = Number(text()) || 0
	}
}
