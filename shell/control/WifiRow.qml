import QtQuick
import Quickshell.Networking
import qs
import qs.ui

// A network: its signal, how it stands, and a way to disconnect from the one
// connected. While `asking`, a field for its password.
Entry {
	id: row

	// A network that went away is null here for a moment, as the row goes.
	readonly property var network: modelData ?? ({})
	readonly property bool takesKey: Wifi.takesKey(network)
	readonly property bool isOpen: Wifi.isOpen(network)
	readonly property bool joinable: network.connected || network.known || isOpen || takesKey
	readonly property string standing: {
		if (network.connected)
			return "Connected";
		if (network.known)
			return "Saved";
		if (isOpen)
			return "Open";
		return takesKey ? "Secured" : "Needs a setup of its own";
	}
	readonly property string failure: Wifi.failure(network)
	property bool asking: false

	signal keyGiven(string key)
	signal keyDropped

	text: network.name ?? ""
	subtext: {
		if (network.state === ConnectionState.Connecting)
			return "Connecting...";
		if (network.state === ConnectionState.Disconnecting)
			return "Disconnecting...";
		return failure || `${standing} · ${Math.round(network.signalStrength * 100)}%`;
	}
	failed: failure !== "" && !network.stateChanging
	pickable: joinable && !network.connected && !network.stateChanging
	opacity: joinable ? 1 : 0.5
	action: network.connected ? "Disconnect" : ""
	onActed: Wifi.disconnect(network)
	onAskingChanged: {
		key.text = "";
		if (asking) {
			key.take();
			Qt.callLater(() => view.positionViewAtIndex(index, ListView.Contain));
		}
	}

	Bars {
		level: row.network.signalStrength
		color: row.network.connected ? Theme.colors.text : Theme.colors.subtext
	}

	below: Item {
		width: row.width
		height: row.asking ? key.height + Theme.u(8) : 0
		visible: row.asking

		TextField {
			id: key

			anchors.left: parent.left
			anchors.leftMargin: Theme.u(8)
			anchors.right: join.left
			anchors.rightMargin: Theme.u(6)
			implicitHeight: Theme.u(34)
			secret: true
			placeholder: "Password"
			onAccepted: {
				if (text !== "")
					row.keyGiven(text);
			}
			// A field lets Enter through, and it'd pick the row, and the arrows,
			// which would take the keys to another row. Escape only gets out of
			// here.
			Keys.onPressed: event => {
				if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
					event.accepted = true;
				} else if (event.key === Qt.Key_Escape) {
					row.keyDropped();
					event.accepted = true;
				}
			}
		}

		Button {
			id: join

			anchors.right: parent.right
			anchors.rightMargin: Theme.u(8)
			height: key.height
			filled: true
			enabled: key.text !== ""
			text: "Connect"
			onClicked: row.keyGiven(key.text)
		}
	}
}
