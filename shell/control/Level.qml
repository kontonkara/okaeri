import QtQuick
import qs
import qs.ui

// A level: what's put in it in front, a slider, and the percentage.
Item {
	id: level

	property alias value: slider.value
	default property alias front: front.data

	signal moved(real wanted)

	width: parent.width
	height: Theme.u(34)

	Item {
		id: front

		width: Theme.u(34)
		height: parent.height
	}

	Slider {
		id: slider

		anchors.left: front.right
		anchors.leftMargin: Theme.u(6)
		anchors.right: percent.left
		anchors.rightMargin: Theme.u(10)
		anchors.verticalCenter: parent.verticalCenter
		onMoved: wanted => level.moved(wanted)
	}

	Text {
		id: percent

		anchors.right: parent.right
		anchors.rightMargin: Theme.u(8)
		anchors.verticalCenter: parent.verticalCenter
		width: Theme.u(36)
		horizontalAlignment: Text.AlignRight
		text: `${Math.round(slider.value * 100)}%`
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		font.features: {
			"tnum": 1
		}
	}
}
