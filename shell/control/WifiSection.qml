import QtQuick
import qs
import qs.ui

// Wi-Fi: on or off, and the networks in reach. A click connects to a known or
// an open one, and asks a secured one's password first.
Section {
	id: section

	property real room: 0
	// The network that's asked for its password.
	property var asking: null
	// Rows stay put meanwhile, or they'd jump as signals change. What's gone
	// still goes, what's new waits at the end.
	property var held: []
	readonly property var networks: {
		if (!asking)
			return Wifi.networks;
		const kept = held.filter(n => Wifi.networks.includes(n));
		return kept.concat(Wifi.networks.filter(n => !kept.includes(n)));
	}

	function pick(network) {
		if (network.connected || network.stateChanging)
			return;
		if (network.known || Wifi.isOpen(network))
			Wifi.connect(network);
		else if (Wifi.takesKey(network))
			asking = asking === network ? null : network;
	}

	name: "wifi"
	wanted: !!Wifi.device
	icon: Wifi.enabled ? "wifi" : "wifiOff"
	title: "Wi-Fi"
	summary: {
		if (Wifi.blocked)
			return "Blocked by a switch";
		if (!Wifi.enabled)
			return "Off";
		return Wifi.connected ? Wifi.connected.name : "Not connected";
	}
	checked: Wifi.enabled
	canSwitch: !Wifi.blocked
	onToggled: wanted => Wifi.setEnabled(wanted)
	onUnfoldedChanged: {
		if (!unfolded)
			asking = null;
	}
	onAskingChanged: {
		held = asking ? Wifi.networks : [];
		// A field keeps the keys even as it hides.
		if (!asking)
			forceActiveFocus();
	}

	// Only when that takes nothing away: a folded section would hide the field
	// that gets the keys, and someone may be typing in another one. The row
	// says what happened either way, and a click asks again.
	Connections {
		target: Wifi

		function onKeyWanted(network) {
			if (section.unfolded && !section.asking)
				section.asking = network;
		}
	}

	Rows {
		values: section.networks
		room: section.room
		empty: "Looking for networks..."
		onActivated: (index, network) => section.pick(network)

		delegate: WifiRow {
			asking: section.asking === modelData
			onKeyDropped: section.asking = null
			onKeyGiven: key => {
				section.asking = null;
				Wifi.connectWithKey(modelData, key);
			}
		}
	}
}
