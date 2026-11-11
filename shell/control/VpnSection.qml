import QtQuick
import qs
import qs.ui

// The VPNs, where NetworkManager has any: all off by the switch, or the one
// last used on, and a click on one takes it up or down.
Section {
	id: section

	name: "vpn"
	wanted: Vpn.connections.length > 0
	icon: "shield"
	title: "VPN"
	summary: Vpn.up.length > 1 ? `${Vpn.up.length} connected` : Vpn.up.length ? Vpn.up[0].name : "Off"
	checked: Vpn.up.length > 0
	onToggled: wanted => Vpn.setEnabled(wanted)

	Rows {
		values: Vpn.connections
		room: section.roomInside
		onActivated: (index, connection) => Vpn.set(connection, !connection.on)

		delegate: Entry {
			id: row

			readonly property var connection: modelData ?? ({})
			readonly property bool wrong: Vpn.failure !== "" && Vpn.failedId === connection.id

			text: connection.name ?? ""
			subtext: connection.busy ? "Working on it..." : wrong ? Vpn.failure : connection.on ? "Connected" : connection.kind ?? ""
			failed: wrong
			pickable: !connection.busy

			Icon {
				name: "shield"
				color: row.connection.on ? Theme.colors.text : Theme.colors.subtext
			}
		}
	}
}
