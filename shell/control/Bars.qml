import QtQuick
import qs

// A signal's strength, 0 to 1, in four bars.
Row {
	id: bars

	property real level: 0
	property color color: Theme.colors.subtext

	height: Theme.u(18)
	spacing: Theme.u(2)

	Repeater {
		model: 4

		Rectangle {
			required property int index

			anchors.bottom: parent.bottom
			width: Theme.u(3)
			height: Theme.u(6 + index * 4)
			radius: Theme.round(width)
			color: index < Math.ceil(bars.level * 4) ? bars.color : Qt.alpha(Theme.colors.text, 0.16)
		}
	}
}
