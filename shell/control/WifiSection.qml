import QtQuick
import qs
import qs.ui

// Wi-Fi: on or off, and the networks in reach. A click connects to a known or
// an open one, and asks a secured one's password first. One that hides its name is
// asked for by that, under the rest.
Section {
	id: section

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
		room: section.roomInside - hidden.height
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

	// A network that doesn't say its name isn't among them: its name and its
	// password, typed.
	Item {
		id: hidden

		property bool asking: false

		width: parent.width
		height: asking ? fields.height + Theme.u(8) : opener.height
		visible: Wifi.enabled

		function join() {
			if (name.text.trim() === "")
				return;
			Wifi.connectHidden(name.text.trim(), key.text);
			asking = false;
		}

		onAskingChanged: {
			name.text = "";
			key.text = "";
			if (asking)
				name.take();
			else
				section.forceActiveFocus();
		}

		Button {
			id: opener

			visible: !hidden.asking
			height: Theme.u(30)
			flat: true
			text: "One that hides its name"
			ink: Theme.colors.subtext
			onClicked: hidden.asking = true
		}

		Column {
			id: fields

			x: Theme.u(8)
			y: Theme.u(4)
			width: parent.width - Theme.u(16)
			visible: hidden.asking
			spacing: Theme.u(6)

			TextField {
				id: name

				width: parent.width
				implicitHeight: Theme.u(34)
				placeholder: "Its name"
				onAccepted: key.take()
				Keys.onEscapePressed: hidden.asking = false
			}

			Item {
				width: parent.width
				height: key.height

				TextField {
					id: key

					anchors.left: parent.left
					anchors.right: join.left
					anchors.rightMargin: Theme.u(6)
					implicitHeight: Theme.u(34)
					secret: true
					placeholder: "Password, if it has one"
					onAccepted: hidden.join()
					Keys.onEscapePressed: hidden.asking = false
				}

				Button {
					id: join

					anchors.right: parent.right
					height: key.height
					filled: true
					enabled: name.text.trim() !== ""
					text: "Connect"
					onClicked: hidden.join()
				}
			}
		}
	}
}
