import QtQuick
import Quickshell.Widgets
import qs
import qs.ui

// A line with a switch: `text`, `subtext` and `image`, those two if it has them.
// It shows `checked` and says toggled(wanted), as Toggle does. With `movable` it
// has a button to go one place up among its like too, which says raised().
Item {
	id: setting

	required property string text
	// What it sets, "section.key" or "theme.key", for its mark; and more words
	// the search finds it by.
	property string holds
	property string words
	property string subtext
	property string image
	property alias checked: toggle.checked
	property bool movable: false

	signal toggled(bool wanted)
	signal raised

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
		anchors.right: raise.visible ? raise.left : toggle.left
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

	Button {
		id: raise

		anchors.right: toggle.left
		anchors.rightMargin: Theme.u(8)
		anchors.verticalCenter: parent.verticalCenter
		visible: setting.movable
		height: Theme.u(24)
		flat: true
		icon: "up"
		iconSize: Theme.u(14)
		tip: "One place up"
		onClicked: setting.raised()
	}

	Toggle {
		id: toggle

		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		onToggled: wanted => setting.toggled(wanted)
	}

	Mark {
		holds: setting.holds
	}
}
