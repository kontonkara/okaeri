import QtQuick
import qs
import qs.ui

// The wired network: up or down by the switch, and what it has while it's up,
// its address, its gateway, its name servers and how fast it goes.
Section {
	id: section

	name: "wired"
	wanted: Wired.plugged
	icon: "ethernet"
	title: "Wired"
	summary: Wired.failure || Wired.summary
	checked: Wired.connected
	canSwitch: Wired.plugged
	onToggled: wanted => Wired.setEnabled(wanted)

	Text {
		width: parent.width
		visible: Wired.details.length === 0
		leftPadding: Theme.u(10)
		topPadding: Theme.u(4)
		bottomPadding: Theme.u(8)
		text: Wired.plugged ? "Nothing to say of it yet" : "No cable in it"
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(1)
	}

	Repeater {
		model: Wired.details

		Item {
			required property var modelData

			width: parent.width
			height: Theme.u(28)

			Text {
				id: label

				anchors.left: parent.left
				anchors.leftMargin: Theme.u(10)
				anchors.verticalCenter: parent.verticalCenter
				text: parent.modelData.text
				color: Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}

			Text {
				anchors.left: label.right
				anchors.leftMargin: Theme.u(12)
				anchors.right: parent.right
				anchors.rightMargin: Theme.u(10)
				anchors.verticalCenter: parent.verticalCenter
				horizontalAlignment: Text.AlignRight
				text: parent.modelData.value
				textFormat: Text.PlainText
				elide: Text.ElideMiddle
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(1)
				font.features: {
					"tnum": 1
				}
			}
		}
	}
}
