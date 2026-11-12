import QtQuick
import qs

// A switch. It shows `checked` and says toggled(wanted): whoever owns the
// value sets it, so it can't show what didn't happen.
Rectangle {
	id: toggle

	property bool checked: false

	signal toggled(bool wanted)

	implicitWidth: Theme.u(40)
	implicitHeight: Theme.u(22)
	radius: Theme.round(height)
	color: checked ? Theme.colors.accent : Qt.alpha(Theme.colors.text, 0.16)
	opacity: enabled ? 1 : 0.5
	activeFocusOnTab: enabled

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
			toggle.toggled(!toggle.checked);
			event.accepted = true;
		}
	}

	Behavior on color {
		enabled: Theme.animate

		ColorAnimation {
			duration: Theme.ms(120)
		}
	}

	Rectangle {
		readonly property real gap: Theme.u(3)

		x: toggle.checked ? parent.width - width - gap : gap
		anchors.verticalCenter: parent.verticalCenter
		width: parent.height - gap * 2
		height: width
		radius: Theme.round(height)
		color: toggle.checked ? Theme.colors.background : Theme.colors.text

		Behavior on x {
			enabled: Theme.animate

			NumberAnimation {
				duration: Theme.ms(120)
				easing.type: Easing.OutCubic
			}
		}
	}

	MouseArea {
		anchors.fill: parent
		enabled: toggle.enabled
		cursorShape: Qt.PointingHandCursor
		onClicked: toggle.toggled(!toggle.checked)
	}

	FocusRing {
		anchors.fill: parent
		visible: toggle.activeFocus
		cornerRadius: toggle.radius
	}
}
