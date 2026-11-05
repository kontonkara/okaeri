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

	// This one tells of a change, but what it reads is what the panel was given:
	// on amdgpu that's far under what was asked at the low end, and a step from it
	// would hardly move.
	FileView {
		path: brightness.directory ? `${brightness.directory}/actual_brightness` : ""
		watchChanges: true
		printErrors: false
		onFileChanged: asked.reload()
	}

	FileView {
		id: asked

		path: brightness.directory ? `${brightness.directory}/brightness` : ""
		blockLoading: true
		printErrors: false
		onLoaded: brightness.current = Number(text()) || 0
	}
}
