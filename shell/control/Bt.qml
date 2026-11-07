pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services

// The default Bluetooth adapter and its devices, connected ones first, then
// paired ones, then those nearby, discovering while the panel is open. What
// goes to Env.act leaves out names: it ends up in logs.
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
		onTriggered: bt.joining = bt.joining.filter(d => d.pairing)
	}
}
