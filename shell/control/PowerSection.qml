import QtQuick
import qs
import qs.services
import qs.ui

// The power profile, the one in use filled, and how the battery is doing.
Card {
	id: section

	width: parent.width
	padding: Theme.u(6)

	Column {
		width: parent.width
		spacing: Theme.u(6)

		Row {
			id: row

			width: parent.width
			spacing: Theme.u(6)

			Repeater {
				model: Power.choices

				Button {
					required property var modelData

					width: (row.width - row.spacing * (Power.choices.length - 1)) / Power.choices.length
					filled: Power.profile === modelData.profile
					flat: !filled
					text: modelData.text
					onClicked: Power.set(modelData.profile)
				}
			}
		}

		Text {
			width: parent.width
			visible: text !== ""
			bottomPadding: Theme.u(2)
			text: Power.batteryLine
			color: Theme.colors.subtext
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}
}
