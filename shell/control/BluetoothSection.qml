import QtQuick
import qs
import qs.ui

// Bluetooth, when there's an adapter: on or off, and the devices, paired and
// nearby. A click connects to one.
Section {
	id: section

	property real room: 0

	name: "bluetooth"
	wanted: !!Bt.adapter
	icon: Bt.enabled ? "bluetooth" : "bluetoothOff"
	title: "Bluetooth"
	summary: {
		if (Bt.blocked)
			return "Blocked by a switch";
		if (!Bt.enabled)
			return "Off";
		if (Bt.connected.length > 1)
			return `${Bt.connected.length} connected`;
		return Bt.connected.length ? Bt.connected[0].name : "Not connected";
	}
	checked: Bt.enabled
	canSwitch: !Bt.blocked
	onToggled: wanted => Bt.setEnabled(wanted)

	Rows {
		values: Bt.devices
		room: section.room
		empty: "Looking for devices..."
		onActivated: (index, device) => Bt.connect(device)

		delegate: BluetoothRow {}
	}
}
