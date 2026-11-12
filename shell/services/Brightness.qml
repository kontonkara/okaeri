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

	// change() left it where it was, at an end of it.
	signal stayed

	// By `by` of all of it, and by a step at least: a panel can have only a few,
	// and a small change would round back to where it was.
	function change(by) {
		if (!available)
			return;
		const steps = Math.max(1, Math.round(Math.abs(by) * maximum));
		const value = within(current + (by < 0 ? -steps : steps));
		if (value === current)
			stayed();
		put(value);
	}

	// To `wanted` of all of it, as near as its steps go: the slider's, which
	// moves by one of them at least.
	function set(wanted) {
		if (available)
			put(within(Math.round(wanted * maximum)));
	}

	// Between the lowest, which is a step at least, and all of it.
	function within(value) {
		return Math.max(Math.max(1, Math.round(lowest * maximum)), Math.min(maximum, value));
	}

	function put(value) {
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
