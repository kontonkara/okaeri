pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.services

// The default Bluetooth adapter and its devices, connected ones first, then
// paired ones, then those nearby, discovering while the panel is open. While
// something pairs, the adapter is pairable, or BlueZ pairs and keeps no key, and
// bluetoothctl, where it's there, answers BlueZ for us as an agent that asks
// nothing; then it's all as it was. What goes to Env.act leaves out names: it
// ends up in logs.
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
			if (!wasPairable)
				Env.act("bluetooth pairable false", () => adapter.pairable = false);
		}
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
	// only then can it be made the default.
	Process {
		id: agent

		command: ["bluetoothctl", "--agent", "NoInputNoOutput"]
		stdinEnabled: true
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
