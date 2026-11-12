import QtQuick
import Quickshell.Bluetooth
import qs
import qs.ui

// A device, by what kind it is: how it stands, and a way to stop one pairing,
// to disconnect from one connected and to forget a paired one. One that didn't
// pair says what it likely needs.
Entry {
	id: row

	// A device that went away is null here for a moment, as the row goes: what's
	// read from it then is nothing.
	readonly property var device: modelData
	readonly property bool connected: device?.connected ?? false
	readonly property bool paired: device?.paired ?? false
	readonly property bool pairing: device?.pairing ?? false
	readonly property bool busy: pairing || device?.state === BluetoothDeviceState.Connecting || device?.state === BluetoothDeviceState.Disconnecting
	// The icon BlueZ gives it, a freedesktop name, as one of ours. Speakers are
	// "audio-card" to BlueZ, as is any other sound device that isn't worn; what
	// has none of ours is a Bluetooth one.
	readonly property string kind: {
		const icon = device?.icon ?? "";
		if (icon === "audio-headset" || icon === "audio-headphones")
			return "headphones";
		if (icon === "audio-input-microphone")
			return "mic";
		if (icon.startsWith("audio-"))
			return "volume";
		if (icon === "input-mouse")
			return "mouse";
		if (icon === "input-keyboard")
			return "keyboard";
		if (icon === "input-gaming")
			return "gamepad";
		if (icon === "phone")
			return "phone";
		return "bluetooth";
	}

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
	action: pairing ? "Cancel" : connected ? "Disconnect" : paired ? "Forget" : ""
	// Only forgetting takes a second click: a pairing is stopped at once.
	risky: action === "Forget"
	onActed: {
		if (pairing)
			Bt.cancel(device);
		else if (connected)
			Bt.disconnect(device);
		else
			Bt.forget(device);
	}

	Icon {
		name: row.kind
		color: row.connected ? Theme.colors.text : Theme.colors.subtext
	}
}
