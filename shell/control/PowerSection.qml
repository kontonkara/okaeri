import QtQuick
import qs
import qs.services
import qs.ui

// The power profile, the one in use filled.
Card {
	id: section

	width: parent.width
	padding: Theme.u(6)

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
}
