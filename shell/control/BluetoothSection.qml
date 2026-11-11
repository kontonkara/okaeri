import QtQuick
import qs
import qs.ui

// Bluetooth, when there's an adapter: on or off, and the devices, paired and
// nearby. A click connects to one. What BlueZ asks of one that's pairing comes
// over them: a code to compare or to type, here or on the device.
Section {
	id: section

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

	Item {
		id: asked

		readonly property string kind: Bt.asking?.kind ?? ""
		readonly property string code: Bt.asking?.code ?? ""
		// Which one isn't said: with one pairing it's that one.
		readonly property string who: Bt.joining.length === 1 ? Bt.joining[0].name : "the device"
		readonly property bool typed: kind === "pin" || kind === "passkey"

		width: parent.width
		height: visible ? box.height + Theme.u(6) : 0
		visible: kind !== ""

		onTypedChanged: {
			field.text = "";
			if (typed)
				field.take();
		}

		Rectangle {
			id: box

			width: parent.width
			height: inside.height + Theme.u(20)
			radius: Math.max(0, Theme.cardRadius - Theme.u(4))
			color: Theme.hover

			Column {
				id: inside

				x: Theme.u(10)
				y: Theme.u(10)
				width: parent.width - Theme.u(20)
				spacing: Theme.u(8)

				// Anyone nearby picks the names: never markup.
				Text {
					width: parent.width
					text: asked.kind === "confirm" ? `Does ${asked.who} show this code too?`
						: asked.kind === "accept" ? `Let ${asked.who} pair?`
						: asked.kind === "pin" ? `The PIN of ${asked.who}`
						: asked.kind === "passkey" ? `The code ${asked.who} shows`
						: `Type this on ${asked.who}, then Enter`
					textFormat: Text.PlainText
					wrapMode: Text.Wrap
					color: Theme.colors.text
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
				}

				Text {
					visible: asked.code !== ""
					text: asked.code
					textFormat: Text.PlainText
					color: Theme.colors.text
					font.family: Theme.font
					font.pixelSize: Theme.fontSize + Theme.u(8)
					font.weight: Font.Bold
					font.letterSpacing: Theme.u(3)
					font.features: {
						"tnum": 1
					}
				}

				Row {
					anchors.right: parent.right
					visible: asked.kind === "confirm" || asked.kind === "accept"
					spacing: Theme.u(6)

					Button {
						height: Theme.u(30)
						text: "No"
						onClicked: Bt.answer("no")
					}

					Button {
						height: Theme.u(30)
						filled: true
						text: "Yes"
						onClicked: Bt.answer("yes")
					}
				}

				Item {
					width: parent.width
					height: field.height
					visible: asked.typed

					TextField {
						id: field

						anchors.left: parent.left
						anchors.right: pair.left
						anchors.rightMargin: Theme.u(6)
						implicitHeight: Theme.u(34)
						placeholder: asked.kind === "pin" ? "PIN" : "Code"
						onAccepted: {
							if (text !== "")
								Bt.answer(text);
						}
					}

					Button {
						id: pair

						anchors.right: parent.right
						height: field.height
						filled: true
						enabled: field.text !== ""
						text: "Pair"
						onClicked: Bt.answer(field.text)
					}
				}
			}
		}
	}

	Rows {
		values: Bt.devices
		room: section.roomInside - asked.height
		empty: "Looking for devices..."
		onActivated: (index, device) => Bt.connect(device)

		delegate: BluetoothRow {}
	}
}
