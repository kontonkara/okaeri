import QtQuick
import Quickshell.Bluetooth
import qs
import qs.ui

// A device: how it stands, and a way to disconnect from one connected and to
// forget a paired one.
Entry {
	id: row

	// A device that went away is null here for a moment, as the row goes.
	readonly property var device: modelData ?? ({})
	readonly property bool busy: device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting

	text: device.name ?? ""
	subtext: {
		if (device.pairing)
			return "Pairing...";
		if (device.state === BluetoothDeviceState.Connecting)
			return "Connecting...";
		if (device.state === BluetoothDeviceState.Disconnecting)
			return "Disconnecting...";
		if (device.connected)
			return device.batteryAvailable ? `Connected · ${Math.round(device.battery * 100)}%` : "Connected";
		return device.paired ? "Paired" : "Nearby";
	}
	pickable: !device.connected && !busy
	action: device.connected ? "Disconnect" : device.paired ? "Forget" : ""
	risky: !device.connected
	onActed: {
		if (device.connected)
			Bt.disconnect(device);
		else
			Bt.forget(device);
	}

	Icon {
		name: "bluetooth"
		color: row.device.connected ? Theme.colors.text : Theme.colors.subtext
	}
}
