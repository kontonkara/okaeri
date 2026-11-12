import QtQuick
import qs
import qs.ui

// A line with a field: `text`, `subtext` if it has one, and `value` in the
// field to start from. Enter keeps what's typed, and so does leaving the field:
// kept(value). Escape puts back what it had.
Item {
	id: field

	required property string text
	property string subtext
	property string placeholder
	property string value
	property real fieldWidth: Theme.u(240)

	signal kept(string value)

	width: parent.width
	height: Theme.u(subtext ? 40 : 34)

	Column {
		anchors.left: parent.left
		anchors.right: input.left
		anchors.rightMargin: Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter

		Text {
			width: parent.width
			text: field.text
			color: Theme.colors.text
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Text {
			width: parent.width
			visible: text !== ""
			text: field.subtext
			textFormat: Text.PlainText
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	TextField {
		id: input

		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		implicitWidth: field.fieldWidth
		implicitHeight: Theme.u(32)
		placeholder: field.placeholder
		text: field.value
		keeps: true
		onAccepted: field.kept(text.trim())
	}
}
