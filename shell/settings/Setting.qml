import QtQuick
import Quickshell.Widgets
import qs
import qs.ui

// A line with a switch: `text`, `subtext` and `image`, those two if it has them.
// It shows `checked` and says toggled(wanted), as Toggle does.
Item {
	id: setting

	required property string text
	property string subtext
	property string image
	property alias checked: toggle.checked

	signal toggled(bool wanted)

	width: parent.width
	height: Theme.u(subtext ? 40 : 30)

	IconImage {
		id: picture

		anchors.verticalCenter: parent.verticalCenter
		visible: setting.image !== ""
		source: setting.image
		implicitSize: Theme.u(20)
	}

	Column {
		anchors.left: picture.visible ? picture.right : parent.left
		anchors.leftMargin: picture.visible ? Theme.u(10) : 0
		anchors.right: toggle.left
		anchors.rightMargin: Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter

		// An app's title can be anything.
		Text {
			width: parent.width
			text: setting.text
			textFormat: Text.PlainText
			color: Theme.colors.text
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Text {
			width: parent.width
			visible: text !== ""
			text: setting.subtext
			textFormat: Text.PlainText
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	Toggle {
		id: toggle

		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		onToggled: wanted => setting.toggled(wanted)
	}
}
