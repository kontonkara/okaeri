import QtQuick
import qs
import qs.control
import qs.ui

// Bluetooth while it's on, or only with a device connected, as
// Settings.bluetooth.show says, and beside it the first device's name, if
// Settings.bluetooth.label says so. A click opens the control center at
// Bluetooth. Only on the bar does it start the Bluetooth service: the control
// center leaves that to its first opening.
Button {
	id: button

	readonly property var devices: Bt.connected
	readonly property bool wanted: Bt.enabled && (Settings.bluetooth.show === "on" || devices.length > 0)

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	longest: Theme.u(140)
	activeFocusOnTab: false
	icon: "bluetooth"
	text: Settings.bluetooth.label === "name" && devices.length > 0 ? devices[0].name : ""
	ink: devices.length > 0 ? Theme.colors.text : Theme.colors.subtext
	tip: devices.length > 0 ? devices.map(device => device.batteryAvailable ? `${device.name} · ${Math.round(device.battery * 100)}%` : device.name).join(", ") : "Bluetooth on, nothing connected"
	onClicked: {
		Control.unfolded = "bluetooth";
		Control.toggle();
	}
}
