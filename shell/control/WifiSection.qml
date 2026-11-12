import QtQuick
import Quickshell.Networking
import qs
import qs.services
import qs.ui

// Wi-Fi: on or off, and the networks in reach. A click connects to a known or
// an open one, and asks a secured one's password first. One that hides its name is
// asked for by that, under the rest, and beside that the one it's on is shared
// with a phone: its name, its password and the code for a phone's camera. A
// network that asks to be signed in to has a button for that.
Section {
	id: section

	// The network that's asked for its password.
	property var asking: null
	// The one it's on, where a phone can join it with no more than a password,
	// and whether that's shown. Watched by its name, which changes only with the
	// network: the list it's found in is made anew as any signal changes.
	readonly property var shareable: Wifi.connected && (Wifi.takesKey(Wifi.connected) || Wifi.isOpen(Wifi.connected)) ? Wifi.connected : null
	readonly property string sharedName: shareable ? shareable.name : ""
	property bool sharing: false
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
		if (!Wifi.connected)
			return "Not connected";
		// What the network part of the bar says of it too.
		const reach = Networking.connectivity;
		const trouble = reach === NetworkConnectivity.Portal ? "Sign in to the network" : reach === NetworkConnectivity.Limited || reach === NetworkConnectivity.None ? "No internet" : "";
		return [Wifi.connected.name, trouble].filter(part => part !== "").join(" · ");
	}
	checked: Wifi.enabled
	canSwitch: !Wifi.blocked
	onToggled: wanted => Wifi.setEnabled(wanted)
	onUnfoldedChanged: {
		if (!unfolded) {
			asking = null;
			sharing = false;
		}
	}
	// Another network, or none: what was shared was that one's.
	onSharedNameChanged: sharing = false
	onSharingChanged: {
		if (sharing && shareable && !Wifi.isOpen(shareable))
			Wifi.readKey();
		else
			Wifi.forgetKey();
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

	// A network that asks to be signed in to first, in a page of its own: one with
	// no https, which the network takes over to show that.
	Button {
		id: signIn

		visible: !!Wifi.connected && Networking.connectivity === NetworkConnectivity.Portal
		height: visible ? Theme.u(30) : 0
		icon: "lock"
		text: "Sign in to the network"
		onClicked: {
			Control.leave();
			Env.act("wifi sign in", () => Qt.openUrlExternally("http://neverssl.com"));
		}
	}

	Rows {
		values: section.networks
		room: section.roomInside - hidden.height - (shareCard.visible ? shareCard.height : 0) - signIn.height
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

	WifiShare {
		id: shareCard

		file: "share-wifi.png"
		visible: section.sharing
		active: section.sharing
		name: section.sharedName
		key: Wifi.key
		open: !!section.shareable && Wifi.isOpen(section.shareable)
		note: Wifi.keyFailure || (Wifi.key === "" ? "Asking for it..." : "")
		failed: Wifi.keyFailure !== ""
	}

	// A network that doesn't say its name isn't among them: its name and its
	// password, typed. The way to share the one it's on is on the same line.
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
			if (asking) {
				section.sharing = false;
				name.take();
			} else {
				section.forceActiveFocus();
			}
		}

		Button {
			id: opener

			visible: !hidden.asking
			height: Theme.u(30)
			flat: true
			// How the last try at one went is here too: it has no row to say it on.
			longest: hidden.width - Theme.u(24) - (sharer.visible ? sharer.width + Theme.u(8) : 0)
			enabled: !Wifi.joining
			text: Wifi.joining ? `Connecting to ${Wifi.joined}...` : Wifi.joinFailure ? `${Wifi.joined}: ${Wifi.joinFailure}` : "One that hides its name"
			ink: Wifi.joinFailure && !Wifi.joining ? Theme.colors.error : Theme.colors.subtext
			onClicked: hidden.asking = true
		}

		// Escape ends the sharing first, where the keys are on this.
		Button {
			id: sharer

			anchors.right: parent.right
			visible: !hidden.asking && !!section.shareable
			height: Theme.u(30)
			flat: true
			icon: section.sharing ? "" : "qr"
			text: section.sharing ? "Done" : "Share"
			tip: section.sharing ? "" : "Its name, its password and a code for a phone"
			ink: Theme.colors.subtext
			onClicked: section.sharing = !section.sharing
			Keys.onEscapePressed: event => {
				event.accepted = section.sharing;
				section.sharing = false;
			}
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
