pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Warmer screens, by wlsunset, which niri lets set the gamma: always, from one
// time to another, or from sunset to sunrise where Settings.nightLight puts you.
// Whether it's on is the control center's, and stays over a reload and a restart
// in the shell's own settings. With a schedule or the sun, turning it off is for
// the night that's on or coming: it's back as set the evening after.
Singleton {
	id: night

	readonly property var own: Settings.nightLight
	// On as the settings have it, and not off for tonight.
	readonly property bool on: own.on && !paused
	property double now: Date.now()
	readonly property bool paused: own.on && kept.pausedUntil > now
	readonly property string pauseLabel: paused ? `Off until ${Qt.formatDateTime(new Date(kept.pausedUntil), Settings.clock.hours12 ? "h:mm AP" : "HH:mm")}` : ""
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
		now = Date.now();
		if (wanted) {
			kept.pausedUntil = 0;
			if (!own.on)
				Settings.set("nightLight", "on", true);
		} else if (own.mode !== "always" && own.on) {
			kept.pausedUntil = morning();
		} else {
			stop();
		}
	}

	// Off, schedule and all, until it's turned on again.
	function stop() {
		kept.pausedUntil = 0;
		Settings.set("nightLight", "on", false);
	}

	// The end of the night that's on or coming: the schedule's end, or by the sun
	// ten in the morning, whichever of those comes next.
	function morning() {
		const [hours, minutes] = (own.mode === "schedule" ? own.until : "10:00").split(":").map(Number);
		const end = new Date();
		end.setHours(hours || 0, minutes || 0, 0, 0);
		if (end.getTime() <= Date.now())
			end.setDate(end.getDate() + 1);
		return end.getTime();
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

		// How warm, in kelvin, for a key or a script: from 2500 to 6000.
		function warmth(kelvin: int): void {
			Settings.set("nightLight", "temperature", Math.max(2500, Math.min(6000, kelvin)));
		}

		function state(): string {
			return JSON.stringify({ on: night.on, available: night.available, paused: night.paused });
		}
	}

	Process {
		running: true
		command: ["sh", "-c", "command -v wlsunset"]
		onExited: code => night.available = code === 0
	}

	// The morning by the clock: a sleep doesn't move a timer on.
	Timer {
		interval: 60000
		running: kept.pausedUntil > 0
		repeat: true
		onTriggered: {
			night.now = Date.now();
			if (kept.pausedUntil <= night.now)
				kept.pausedUntil = 0;
		}
	}

	PersistentProperties {
		id: kept

		property double pausedUntil: 0

		reloadableId: "nightLight"
	}

	Process {
		id: sunset

		command: ["wlsunset"].concat(night.args)
	}
}
