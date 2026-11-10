import QtQuick
import Quickshell.Bluetooth
import qs
import qs.ui

// A device: how it stands, and a way to disconnect from one connected and to
// forget a paired one. One that didn't pair says what it likely needs.
Entry {
	id: row

	// A device that went away is null here for a moment, as the row goes: what's
	// read from it then is nothing.
	readonly property var device: modelData
	readonly property bool connected: device?.connected ?? false
	readonly property bool paired: device?.paired ?? false
	readonly property bool busy: (device?.pairing ?? false) || device?.state === BluetoothDeviceState.Connecting || device?.state === BluetoothDeviceState.Disconnecting

	text: device?.name ?? ""
	subtext: {
		if (!device)
			return "";
		if (device.pairing)
			return "Pairing...";
		if (device.state === BluetoothDeviceState.Connecting)
			return "Connecting...";
		if (device.state === BluetoothDeviceState.Disconnecting)
			return "Disconnecting...";
		if (device.connected)
			return device.batteryAvailable ? `Connected · ${Math.round(device.battery * 100)}%` : "Connected";
		if (Bt.failed.includes(device))
			return "Didn't pair: put it in pairing mode and try again";
		return device.paired ? "Paired" : "Nearby";
	}
	pickable: !connected && !busy
	action: connected ? "Disconnect" : paired ? "Forget" : ""
	risky: !connected
	onActed: {
		if (connected)
			Bt.disconnect(device);
		else
			Bt.forget(device);
	}

	Icon {
		name: "bluetooth"
		color: row.connected ? Theme.colors.text : Theme.colors.subtext
	}
}
