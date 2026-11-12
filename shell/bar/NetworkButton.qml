import QtQuick
import Quickshell.Networking
import qs
import qs.control
import qs.ui

// How the machine is online: by wire, by Wi-Fi with its signal, or not, and
// whether the network says there's no internet past it or a page to sign in on.
// Beside it the network's name, if Settings.network.label says so. A click opens
// the control center at Wi-Fi. Only on the bar does it start the Wi-Fi service:
// the control center leaves that to its first opening.
BarButton {
	id: button

	readonly property var wired: Networking.devices.values.find(device => device.type === DeviceType.Wired && device.connected) ?? null
	readonly property var network: Wifi.connected
	readonly property int strength: network ? Math.round(network.signalStrength * 100) : 0
	readonly property int connectivity: Networking.connectivity
	readonly property bool online: !!wired || !!network
	// What the network says past it, where it can tell.
	readonly property string trouble: !online ? "" : connectivity === NetworkConnectivity.Portal ? "Sign in to the network" : connectivity === NetworkConnectivity.Limited || connectivity === NetworkConnectivity.None ? "No internet" : ""
	readonly property bool wanted: !!wired || !!Wifi.device

	visible: wanted
	longest: Theme.u(140)
	icon: wired ? "ethernet" : !Wifi.enabled ? "wifiOff" : !network ? "wifi" : strength > 66 ? "wifi" : strength > 33 ? "wifi2" : "wifi1"
	text: Settings.network.label === "name" && online && !stacked ? (wired ? "Wired" : network.name) : ""
	ink: trouble !== "" ? Theme.colors.error : online ? Theme.colors.text : Theme.colors.subtext
	tip: {
		const about = wired ? ["Wired", wired.linkSpeed > 0 ? `${wired.linkSpeed} Mb/s` : ""] : !Wifi.enabled ? ["Wi-Fi off"] : network ? [network.name, `${strength}%`] : ["Not connected"];
		return about.concat([trouble]).filter(part => part !== "").join(" · ");
	}
	onClicked: {
		Control.unfolded = "wifi";
		Control.toggle();
	}
}
