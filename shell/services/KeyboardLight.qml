pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The keyboard's backlight, where it has one the kernel knows: 0 to 1, read
// from sysfs, and set through logind, which lets the session's user do that.
// Its own keys change it too, and the kernel says when they did.
Singleton {
	id: light

	readonly property string leds: "/sys/class/leds"
	property string device: ""
	readonly property string directory: device ? `${leds}/${device}` : ""
	readonly property int maximum: Number(maximumFile.text()) || 0
	readonly property bool available: device !== "" && maximum > 0
	property int current: 0
	readonly property real level: available ? current / maximum : 0

	// By `by` of all of it, and by a step at least: some have only a few.
	function change(by) {
		const steps = Math.max(1, Math.round(Math.abs(by) * maximum));
		put(current + (by < 0 ? -steps : steps));
	}

	function set(wanted) {
		put(Math.round(wanted * maximum));
	}

	function put(wanted) {
		if (!available)
			return;
		const value = Math.max(0, Math.min(maximum, wanted));
		Env.act(`keyboard light ${value}`, () => {
			// Shown at once; the file follows.
			current = value;
			setter.command = ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetBrightness", "ssu", "leds", device, String(value)];
			setter.running = true;
		});
	}

	Process {
		running: true
		command: ["ls", light.leds]

		stdout: StdioCollector {
			onStreamFinished: light.device = text.split("\n").find(name => name.includes("kbd_backlight")) ?? ""
		}
	}

	Process {
		id: setter
	}

	FileView {
		id: maximumFile

		path: light.directory ? `${light.directory}/max_brightness` : ""
		blockLoading: true
		printErrors: false
	}

	FileView {
		path: light.directory ? `${light.directory}/brightness_hw_changed` : ""
		watchChanges: true
		printErrors: false
		onFileChanged: asked.reload()
	}

	FileView {
		id: asked

		path: light.directory ? `${light.directory}/brightness` : ""
		blockLoading: true
		printErrors: false
		onLoaded: light.current = Number(text()) || 0
	}
}
