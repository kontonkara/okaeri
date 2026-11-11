pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.services

// The default Bluetooth adapter and its devices, connected ones first, then
// paired ones, then those nearby, discovering while the panel is open. While
// something pairs, the adapter is pairable, or BlueZ pairs and keeps no key, and
// bluetoothctl, where it's there, answers BlueZ for us as an agent: what BlueZ
// asks of it, a code to compare, to type here or on the device, is `asking`, for
// the page to show and answer(); then it's all as it was. What goes to Env.act
// leaves out names and codes: it ends up in logs.
Singleton {
	id: bt

	property var adapter: Bluetooth.defaultAdapter
	readonly property bool enabled: !!adapter && adapter.enabled
	readonly property bool blocked: !!adapter && adapter.state === BluetoothAdapterState.Blocked
	readonly property var devices: {
		// Those nearby with no name are only addresses, nothing to pick by.
		const seen = adapter ? adapter.devices.values.filter(d => d.paired || d.deviceName !== "") : [];
		return seen.sort((a, b) => b.connected - a.connected || b.paired - a.paired || a.name.localeCompare(b.name));
	}
	readonly property var connected: devices.filter(d => d.connected)
	readonly property bool discovering: Control.open && enabled
	// Being paired: each connects when that's done.
	property var joining: []
	// What didn't pair, the last time it was tried: likely not ready for it.
	property var failed: []
	readonly property bool pairing: joining.length > 0
	// Whether the adapter was pairable before something was paired.
	property bool wasPairable: true
	property bool hasAgent: false
	// What BlueZ wants to know, or says, of what's pairing: { kind, code }, kind
	// being "confirm" for a code that's to be the same on both, "accept" for a yes
	// or no with no code, "pin" and "passkey" for one to type here, and "show" for
	// one to type on the device. Null with nothing asked.
	property var asking: null
	// What the agent has said so far, without the colors.
	property string heard

	onPairingChanged: {
		if (!adapter)
			return;
		if (pairing) {
			wasPairable = adapter.pairable;
			if (!wasPairable)
				Env.act("bluetooth pairable true", () => adapter.pairable = true);
			if (hasAgent)
				Env.act("bluetooth agent", () => agent.running = true);
		} else {
			agent.running = false;
			asking = null;
			heard = "";
			if (!wasPairable)
				Env.act("bluetooth pairable false", () => adapter.pairable = false);
		}
	}

	// What bluetoothctl prints, as it comes: a question has no end of line, so
	// it's all looked through for the last thing asked or said.
	function hear(text) {
		heard = (heard + text.replace(/\x1b\[[0-9;]*[A-Za-z]|[\x01\x02\r]/g, "")).slice(-2000);
		const kinds = [
			{ kind: "confirm", says: /Confirm passkey (\d+) \(yes\/no\):/g },
			{ kind: "accept", says: /(?:Accept pairing|Authorize service \S+) \(yes\/no\):/g },
			{ kind: "pin", says: /Enter PIN code:/g },
			{ kind: "passkey", says: /Enter passkey \(number in 0-999999\):/g },
			{ kind: "show", says: /\[agent\] (?:PIN code|Passkey): (\S+)/g },
			{ kind: "", says: /Request canceled|Agent unregistered/g }
		];
		let last = null;
		kinds.forEach(entry => {
			for (let found = entry.says.exec(heard); found; found = entry.says.exec(heard)) {
				if (!last || found.index >= last.at)
					last = { at: found.index, kind: entry.kind, code: found[1] ?? "" };
			}
		});
		if (!last)
			return;
		// What's answered or over isn't asked again by what comes after it.
		heard = heard.slice(last.at + 1);
		asking = last.kind ? { kind: last.kind, code: last.code } : null;
		if (asking)
			Control.show("bluetooth");
	}

	// What's typed or chosen for the question there is: "yes", "no" or a code.
	function answer(text) {
		const kind = asking?.kind ?? "";
		asking = null;
		Env.act(`bluetooth answer ${kind}${text === "yes" || text === "no" ? ` ${text}` : ""}`, () => agent.write(`${text}\n`));
	}

	function discover() {
		Env.act(`bluetooth discovery ${discovering}`, () => {
			if (adapter)
				adapter.discovering = discovering;
		});
	}

	function setEnabled(wanted) {
		Env.act(`bluetooth ${wanted}`, () => adapter.enabled = wanted);
	}

	function connect(device) {
		if (device.pairing || device.state !== BluetoothDeviceState.Disconnected)
			return;
		failed = failed.filter(d => d !== device);
		if (device.paired) {
			Env.act("bluetooth connect", () => device.connect());
		} else {
			if (!joining.includes(device))
				joining = joining.concat([device]);
			Env.act("bluetooth pair", () => device.pair());
		}
	}

	function disconnect(device) {
		Env.act("bluetooth disconnect", () => device.disconnect());
	}

	function forget(device) {
		Env.act("bluetooth forget", () => device.forget());
	}

	onDiscoveringChanged: discover()

	// This starts with the first opening, already discovering if the adapter
	// is there: that's no change.
	Component.onCompleted: {
		if (discovering)
			discover();
	}

	Variants {
		model: bt.joining

		Connections {
			required property var modelData

			target: modelData

			function onPairedChanged() {
				const device = modelData;
				// Trusted, or it needs someone to say yes each time it comes
				// back.
				Env.act("bluetooth trust and connect", () => {
					device.trusted = true;
					device.connect();
				});
				bt.joining = bt.joining.filter(d => d !== device);
			}

			function onPairingChanged() {
				if (!modelData.pairing)
					settling.restart();
			}
		}
	}

	// A pairing that failed only ends, and `paired` may come just after the
	// end of one that didn't: what's still here a moment later has failed.
	Timer {
		id: settling

		interval: 3000
		onTriggered: {
			const over = bt.joining.filter(d => !d.pairing);
			bt.failed = bt.failed.concat(over.filter(d => !d.paired));
			bt.joining = bt.joining.filter(d => d.pairing);
		}
	}

	Process {
		running: true
		command: ["sh", "-c", "command -v bluetoothctl"]
		onExited: code => bt.hasAgent = code === 0
	}

	// An agent for as long as something pairs, the default one meanwhile: BlueZ
	// asks that one for what's paired from here. It registers as it starts, and
	// only then can it be made the default. It says it can show a code and take
	// one: with a device that can do neither BlueZ asks nothing.
	Process {
		id: agent

		command: ["bluetoothctl", "--agent", "KeyboardDisplay"]
		stdinEnabled: true
		stdout: SplitParser {
			splitMarker: ""
			onRead: text => bt.hear(text)
		}
		onStarted: defaulting.restart()
		onRunningChanged: {
			if (!running)
				defaulting.stop();
		}
	}

	Timer {
		id: defaulting

		interval: 500
		onTriggered: agent.write("default-agent\n")
	}
}
