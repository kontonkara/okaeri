pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.services

// The Wi-Fi device and its networks, best first, scanning while the panel is
// open. What goes to Env.act leaves out names: it ends up in logs.
Singleton {
	id: wifi

	property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
	property bool enabled: Networking.wifiEnabled
	readonly property bool blocked: !Networking.wifiHardwareEnabled
	readonly property var networks: {
		const seen = device ? device.networks.values.filter(n => n.name !== "") : [];
		return seen.sort((a, b) => b.connected - a.connected || b.known - a.known || b.signalStrength - a.signalStrength);
	}
	readonly property var connected: networks.find(n => n.connected) || null
	readonly property bool scanning: Control.open && !!device && enabled

	// A network turned down the password it has, or has none.
	signal keyWanted(var network)

	// What a network needs of us.
	function isOpen(network) {
		return [WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.security);
	}

	function takesKey(network) {
		return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security);
	}

	// Why its last try failed, if it did.
	function failure(network) {
		const watch = watches.instances.find(w => w.modelData === network);
		return watch ? watch.failure : "";
	}

	function reason(failed) {
		switch (failed) {
		case ConnectionFailReason.NoSecrets:
			return "Wrong password";
		case ConnectionFailReason.WifiAuthTimeout:
			return "Timed out";
		case ConnectionFailReason.WifiNetworkLost:
			return "Out of reach";
		default:
			return "Couldn't connect";
		}
	}

	function scan() {
		Env.act(`wifi scan ${scanning}`, () => {
			if (device)
				device.scannerEnabled = scanning;
		});
	}

	function setEnabled(wanted) {
		Env.act(`wifi ${wanted}`, () => Networking.wifiEnabled = wanted);
	}

	function connect(network) {
		Env.act("wifi connect", () => network.connect());
	}

	function connectWithKey(network, key) {
		Env.act("wifi connect with a key", () => network.connectWithPsk(key));
	}

	// One that doesn't say its name, by that name, with its password if it has one:
	// nmcli asks NetworkManager, as there's no network to ask here.
	function connectHidden(name, key) {
		Env.act("wifi connect hidden", () => Quickshell.execDetached(["nmcli", "device", "wifi", "connect", name].concat(key ? ["password", key] : [], ["hidden", "yes"])));
	}

	function disconnect(network) {
		Env.act("wifi disconnect", () => network.disconnect());
	}

	function forget(network) {
		Env.act("wifi forget", () => network.forget());
	}

	onScanningChanged: scan()

	// This starts with the first opening, already scanning if the device is
	// there: that's no change.
	Component.onCompleted: {
		if (scanning)
			scan();
	}

	// A try can end with the panel closed and its rows gone, so how it ended
	// waits here until the next one.
	Variants {
		id: watches

		model: wifi.device ? wifi.device.networks.values : []

		Connections {
			required property var modelData
			property string failure

			target: modelData

			function onConnectionFailed(failed) {
				failure = wifi.reason(failed);
				if (failed === ConnectionFailReason.NoSecrets && wifi.takesKey(modelData))
					wifi.keyWanted(modelData);
			}

			function onStateChanged() {
				if (modelData.state === ConnectionState.Connecting || modelData.connected)
					failure = "";
			}
		}
	}
}
