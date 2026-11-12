pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.services

// The Wi-Fi device and its networks, best first, scanning while the panel is
// open. What goes to Env.act leaves out names and passwords: it ends up in logs.
Singleton {
	id: wifi

	// For what Quickshell doesn't do itself: one that hides its name, the password
	// of the one it's on, and the hotspot. Whether it's there, taken as so until
	// it's been looked for: NetworkManager, which the rest goes by, has it.
	readonly property string tool: "nmcli"
	property bool hasTool: true
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

	// The try at one that doesn't say its name: whether it's going on, the name, and
	// why the last one failed, or "".
	readonly property bool joining: join.running
	property string joined: ""
	property string joinFailure: ""

	// One that doesn't say its name, by that name, with its password if it has one:
	// nmcli asks NetworkManager, as there's no network to ask here.
	function connectHidden(name, key) {
		joinFailure = "";
		joined = name;
		Env.act("wifi connect hidden", () => {
			join.command = [tool, "device", "wifi", "connect", name].concat(key ? ["password", key] : [], ["hidden", "yes"]);
			join.running = true;
		});
	}

	// What a phone's camera reads as a network to join: its name, and its
	// password unless it has none, with what would end a field taken as text.
	function code(name, key) {
		const plain = text => text.replace(/[\\;,:"]/g, "\\$&");
		return key ? `WIFI:T:WPA;S:${plain(name)};P:${plain(key)};;` : `WIFI:T:nopass;S:${plain(name)};;`;
	}

	// The password of the one it's on, for a phone to join it by: asked of
	// NetworkManager as it's shared, where polkit may want a word first, and let
	// go of as that ends. Why it couldn't be had, or "".
	property bool sharing: false
	property string key
	property string keyFailure
	readonly property bool readingKey: reader.running

	function readKey() {
		sharing = true;
		key = "";
		keyFailure = "";
		if (!hasTool) {
			keyFailure = "It needs nmcli, which isn't here";
			return;
		}
		reader.command = [tool, "device", "wifi", "show-password"].concat(device?.name ? ["ifname", device.name] : []);
		reader.running = true;
	}

	function forgetKey() {
		sharing = false;
		reader.running = false;
		key = "";
		keyFailure = "";
	}

	// The page that showed it can go with the panel before it's folded.
	Connections {
		target: Control

		function onOpenChanged() {
			if (!Control.open)
				wifi.forgetKey();
		}
	}

	// It says "Password: " and the password, in English as asked; or nothing of
	// that, and why on its other stream.
	Process {
		id: reader

		environment: ({
				LC_ALL: "C"
			})
		stdout: StdioCollector {
			id: readerSaid
		}
		stderr: StdioCollector {
			id: readerComplained
		}
		onExited: code => {
			if (!wifi.sharing)
				return;
			const line = readerSaid.text.split("\n").find(said => said.startsWith("Password: "));
			if (code === 0 && line !== undefined && line.length > 10) {
				wifi.key = line.slice(10);
				return;
			}
			const why = readerComplained.text.trim().split("\n").pop().replace(/^(Error|Warning): /, "");
			wifi.keyFailure = why ? why.charAt(0).toUpperCase() + why.slice(1) : "Couldn't get its password";
		}
	}

	Process {
		running: true
		command: ["sh", "-c", `command -v ${wifi.tool}`]
		onExited: code => wifi.hasTool = code === 0
	}

	Process {
		id: join

		stderr: StdioCollector {
			id: joinSaid
		}
		onExited: code => {
			if (code !== 0)
				wifi.joinFailure = joinSaid.text.trim().split("\n").pop().replace(/^Error: /, "") || "Couldn't connect";
		}
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
