import QtQuick
import Quickshell.Widgets
import qs
import qs.ui

// A line to pick one of `options`, { value, text }, by the arrows or the wheel:
// `text`, and `subtext` and `image` if it has them. It shows `value`, and says
// chosen(value), as Choice does for numbers.
Item {
	id: pick

	required property string text
	property string subtext
	property string image
	required property var options
	property var value
	// How wide what it shows gets.
	property real valueWidth: Theme.u(100)
	readonly property int at: options.findIndex(option => option.value === value)

	signal chosen(var value)

	function step(by) {
		const next = options[at + by];
		if (next)
			chosen(next.value);
	}

	width: parent.width
	height: Theme.u(subtext ? 40 : 30)

	IconImage {
		id: picture

		anchors.verticalCenter: parent.verticalCenter
		visible: pick.image !== ""
		source: pick.image
		implicitSize: Theme.u(20)
	}

	Column {
		anchors.left: picture.visible ? picture.right : parent.left
		anchors.leftMargin: picture.visible ? Theme.u(10) : 0
		anchors.right: picker.left
		anchors.rightMargin: Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter

		Text {
			width: parent.width
			text: pick.text
			textFormat: Text.PlainText
			color: Theme.colors.text
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Text {
			width: parent.width
			visible: text !== ""
			text: pick.subtext
			textFormat: Text.PlainText
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	Row {
		id: picker

		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter

		Button {
			height: Theme.u(28)
			flat: true
			enabled: pick.at > 0
			icon: "back"
			onClicked: pick.step(-1)
		}

		Text {
			anchors.verticalCenter: parent.verticalCenter
			width: pick.valueWidth
			horizontalAlignment: Text.AlignHCenter
			text: pick.options[pick.at]?.text ?? ""
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Button {
			height: Theme.u(28)
			flat: true
			enabled: pick.at < pick.options.length - 1
			icon: "chevron"
			onClicked: pick.step(1)
		}
	}
}
