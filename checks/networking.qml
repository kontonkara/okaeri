import QtQuick
import Quickshell
import Quickshell.Networking

// Read only: what Quickshell's Networking sees here, a scan included. It
// connects to nothing, and prints counts, no network names.
ShellRoot {
	id: root

	readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null

	onWifiChanged: {
		if (wifi)
			wifi.scannerEnabled = true;
	}

	Timer {
		running: true
		interval: 12000
		onTriggered: {
			const networks = root.wifi ? root.wifi.networks.values : [];
			console.info("okaeri: backend", NetworkBackendType.toString(Networking.backend), "wifi enabled", Networking.wifiEnabled);
			console.info("okaeri: devices", Networking.devices.values.map(d => DeviceType.toString(d.type)).join(" "));
			console.info("okaeri: scanning", root.wifi ? root.wifi.scannerEnabled : "no wifi");
			console.info("okaeri: wifi networks", networks.length, "known", networks.filter(n => n.known).length, "connected", networks.filter(n => n.connected).length);
			console.info("okaeri: security", [...new Set(networks.map(n => WifiSecurityType.toString(n.security)))].join(", "));
			console.info("okaeri: connectWithPsk", networks.length ? typeof networks[0].connectWithPsk : "no network");
			Qt.quit();
		}
	}
}
