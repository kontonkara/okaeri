pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Phones and the like through KDE Connect, its daemon running and the phone
// paired: those in reach, each with its charge, as kdeconnect-cli and the daemon
// on the session bus say, looked at every half a minute. The daemon isn't
// started for that: with it off, there's nothing. One rings to be found,
// is pinged, or is sent what's on the clipboard. What the phone says comes as
// the daemon's notifications, into the history as any app's.
Singleton {
	id: phone

	// For the list and what's done: a test has its own of both.
	readonly property string tool: "kdeconnect-cli"
	readonly property string reader: "busctl"
	// { id, name, charge, charging }, charge -1 where it doesn't say.
	property var devices: []
	// No kdeconnect-cli here: no more looks, as there'd be nothing to see.
	property bool absent: false

	function look() {
		listing.running = true;
	}

	// A line each: its id and name, a tab apart, and what busctl said of its
	// battery, as "i 80 b false".
	function read(text) {
		const found = text.split("\n").filter(line => line.includes("\t")).map(line => {
			const [id, name, battery] = line.split("\t");
			const charge = (battery ?? "").match(/^i (\d+)/);
			return { id, name, charge: charge ? Number(charge[1]) : -1, charging: / b true/.test(battery ?? "") };
		});
		if (JSON.stringify(found) !== JSON.stringify(devices))
			devices = found;
	}

	// What kdeconnect-cli does to `device`, by its flag: "ring", "ping" or
	// "send-clipboard".
	function ask(device, what) {
		Env.act(`phone ${what}`, () => Quickshell.execDetached([tool, "-d", device.id, `--${what}`]));
	}

	Process {
		id: listing

		command: ["sh", "-c", 'command -v "$1" >/dev/null || exit 3; "$2" --user status org.kde.kdeconnect >/dev/null 2>&1 || exit 0; "$1" -a --id-name-only 2>/dev/null | while read -r id name; do printf "%s\\t%s\\t" "$id" "$name"; "$2" --user get-property org.kde.kdeconnect "/modules/kdeconnect/devices/$id/battery" org.kde.kdeconnect.device.battery charge isCharging 2>/dev/null | tr "\\n" " "; echo; done', "sh", phone.tool, phone.reader]
		stdout: StdioCollector {
			onStreamFinished: phone.read(text)
		}
		onExited: code => phone.absent = code === 3
	}

	Timer {
		interval: 30000
		running: !phone.absent
		repeat: true
		triggeredOnStart: true
		onTriggered: phone.look()
	}

	// `okaeri phone list` says what's in reach, as JSON; ring, ping and clipboard
	// are for the first of them, the only one most of the time.
	IpcHandler {
		target: "phone"

		function list(): string {
			return JSON.stringify(phone.devices.map(device => ({ name: device.name, charge: device.charge, charging: device.charging })));
		}

		function look(): void {
			phone.look();
		}

		function ring(): void {
			if (phone.devices.length > 0)
				phone.ask(phone.devices[0], "ring");
		}

		function ping(): void {
			if (phone.devices.length > 0)
				phone.ask(phone.devices[0], "ping");
		}

		function clipboard(): void {
			if (phone.devices.length > 0)
				phone.ask(phone.devices[0], "send-clipboard");
		}
	}
}
