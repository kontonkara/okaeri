import QtQuick
import qs
import qs.ui

// A level: what's put in it in front, a slider, and the percentage.
Item {
	id: level

	property alias value: slider.value
	// What the full slider is, for the percentage: past 1 for a volume that goes
	// further.
	property real full: 1
	// Over the slider, for one that needs saying what it is.
	property string label: ""
	default property alias front: front.data

	signal moved(real wanted)

	width: parent.width
	height: Theme.u(label ? 44 : 34)

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
		anchors.verticalCenterOffset: level.label ? Theme.u(8) : 0
		onMoved: wanted => level.moved(wanted)
	}

	Text {
		anchors.left: slider.left
		anchors.right: slider.right
		anchors.top: parent.top
		anchors.topMargin: Theme.u(4)
		visible: level.label !== ""
		text: level.label
		textFormat: Text.PlainText
		color: Theme.colors.subtext
		elide: Text.ElideRight
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}

	Text {
		id: percent

		anchors.right: parent.right
		anchors.rightMargin: Theme.u(8)
		anchors.verticalCenter: parent.verticalCenter
		width: Theme.u(36)
		horizontalAlignment: Text.AlignRight
		text: `${Math.round(slider.value * level.full * 100)}%`
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		font.features: {
			"tnum": 1
		}
	}
}
