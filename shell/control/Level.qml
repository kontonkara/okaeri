import QtQuick
import qs
import qs.ui

// A level: what's put in it in front, a slider, and the percentage, or the
// step for one of `steps`, and with `opens`, a page by that name, an arrow to
// it, and a right click anywhere on it opens it too, as one on a tile opens what
// else the tile can do.
Item {
	id: level

	property alias value: slider.value
	// How far the wheel and the arrows take it.
	property alias step: slider.step
	// What the full slider is, for the percentage: past 1 for a volume that goes
	// further.
	property real full: 1
	// Over the slider, for one that needs saying what it is.
	property string label: ""
	// How many steps it has, for one of only a few, like a keyboard's light: it
	// then says which of them it's at, or "Off", as a percentage would make it
	// look finer than it is. 0 for a percentage.
	property int steps: 0
	property string opens
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

		anchors.right: arrow.visible ? arrow.left : parent.right
		anchors.rightMargin: Theme.u(arrow.visible ? 2 : 8)
		anchors.verticalCenter: parent.verticalCenter
		width: Theme.u(36)
		horizontalAlignment: Text.AlignRight
		text: {
			if (level.steps > 0 && level.steps <= 5) {
				const at = Math.round(slider.value * level.steps);
				return at === 0 ? "Off" : `${at}/${level.steps}`;
			}
			return `${Math.round(slider.value * level.full * 100)}%`;
		}
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		font.features: {
			"tnum": 1
		}
	}

	Button {
		id: arrow

		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		height: Theme.u(30)
		visible: level.opens !== ""
		flat: true
		icon: "chevron"
		iconSize: Theme.u(16)
		onClicked: Control.unfolded = level.opens
	}

	TapHandler {
		acceptedButtons: Qt.RightButton
		enabled: level.opens !== ""
		onTapped: Control.unfolded = level.opens
	}
}
