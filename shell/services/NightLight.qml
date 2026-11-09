pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Warmer screens, by wlsunset, which niri lets set the gamma: always, from one
// time to another, or from sunset to sunrise where Settings.nightLight puts you.
// Whether it's on is the control center's, and stays over a reload and a restart
// in the shell's own settings.
Singleton {
	id: night

	readonly property var own: Settings.nightLight
	readonly property bool on: own.on
	// Whether wlsunset is there to do it.
	property bool available: false
	readonly property int warm: Math.max(1000, Math.min(6500, own.temperature))
	readonly property var args: {
		const base = ["-t", String(warm)];
		if (own.mode === "schedule")
			return base.concat(["-T", "6500", "-s", own.from, "-S", own.until, "-d", "1800"]);
		if (own.mode === "sun")
			return base.concat(["-T", "6500", "-l", String(own.latitude), "-L", String(own.longitude)]);
		// The same by day and by night: it has to be warmer by day, by a degree.
		return base.concat(["-T", String(warm + 1)]);
	}
	readonly property string summary: own.mode === "schedule" ? `${own.from} to ${own.until}, ${warm} K` : own.mode === "sun" ? `Sunset to sunrise, ${warm} K` : `${warm} K`

	function set(wanted) {
		Settings.set("nightLight", "on", wanted);
	}

	// `steps` of 250 K, warmer for fewer than none.
	function step(steps) {
		Settings.set("nightLight", "temperature", Math.max(2500, Math.min(6000, warm + steps * 250)));
	}

	function start() {
		sunset.running = false;
		if (on && available)
			Env.act(`night light ${args.join(" ")}`, () => Qt.callLater(() => sunset.running = night.on));
	}

	onOnChanged: start()
	onArgsChanged: start()
	onAvailableChanged: start()

	IpcHandler {
		target: "night"

		function toggle(): void {
			night.set(!night.on);
		}

		function state(): string {
			return JSON.stringify({ on: night.on, available: night.available });
		}
	}

	Process {
		running: true
		command: ["sh", "-c", "command -v wlsunset"]
		onExited: code => night.available = code === 0
	}

	Process {
		id: sunset

		command: ["wlsunset"].concat(night.args)
	}
}
