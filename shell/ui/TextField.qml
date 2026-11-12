import QtQuick
import qs

// A line of text. `icon` goes in front of it; `secret` hides what's typed,
// with an eye to show it. Enter is accepted(), and with `shifted` Shift+Enter
// is shiftAccepted(). With `keeps`, as a setting's field has it, leaving it
// with something else in it than it came with is accepted() too, and Escape
// puts that back first; `wrong` marks what can't be kept.
Rectangle {
	id: field

	property alias text: input.text
	property string placeholder
	property string icon
	property bool secret: false
	property bool revealed: false
	property bool shifted: false
	property bool keeps: false
	property bool wrong: false
	// What was in it as the keys came to it, or as it was last accepted.
	property string cameWith

	signal accepted
	signal shiftAccepted

	// `focus: true` on the field means the text.
	onActiveFocusChanged: {
		if (activeFocus)
			input.forceActiveFocus();
	}

	function take() {
		input.forceActiveFocus();
	}

	implicitWidth: Theme.u(260)
	implicitHeight: Theme.u(38)
	radius: Theme.round(height)
	color: Theme.surface
	border.width: Math.max(1, Theme.u(input.activeFocus ? 2 : 1))
	border.color: wrong ? Theme.colors.error : input.activeFocus ? Theme.colors.accent : Theme.border
	opacity: enabled ? 1 : 0.5

	Row {
		id: leading

		anchors.left: parent.left
		anchors.leftMargin: Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter

		Icon {
			visible: field.icon !== ""
			name: field.icon
			color: Theme.colors.subtext
		}
	}

	TextInput {
		id: input

		anchors.left: leading.right
		anchors.leftMargin: field.icon !== "" ? Theme.u(8) : 0
		anchors.right: eye.visible ? eye.left : parent.right
		anchors.rightMargin: eye.visible ? Theme.u(4) : Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter
		activeFocusOnTab: field.enabled
		clip: true
		selectByMouse: true
		echoMode: field.secret && !field.revealed ? TextInput.Password : TextInput.Normal
		color: Theme.colors.text
		selectionColor: Theme.colors.accent
		selectedTextColor: Theme.colors.background
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		onAccepted: {
			field.cameWith = text;
			field.accepted();
		}
		onActiveFocusChanged: {
			if (activeFocus) {
				field.cameWith = text;
			} else if (field.keeps && text !== field.cameWith) {
				field.cameWith = text;
				field.accepted();
			}
		}

		Keys.onPressed: event => {
			if (field.keeps && event.key === Qt.Key_Escape && text !== field.cameWith) {
				text = field.cameWith;
				event.accepted = true;
				return;
			}
			if (field.shifted && event.modifiers & Qt.ShiftModifier && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
				field.shiftAccepted();
				event.accepted = true;
			}
		}

		Text {
			anchors.fill: parent
			visible: input.text === ""
			text: field.placeholder
			textFormat: Text.PlainText
			color: Theme.colors.dim
			elide: Text.ElideRight
			font: input.font
		}
	}

	Button {
		id: eye

		anchors.right: parent.right
		anchors.rightMargin: Theme.u(4)
		anchors.verticalCenter: parent.verticalCenter
		height: parent.height - Theme.u(8)
		visible: field.secret
		flat: true
		icon: field.revealed ? "eyeOff" : "eye"
		ink: Theme.colors.subtext
		activeFocusOnTab: false
		onClicked: field.revealed = !field.revealed
	}
}
