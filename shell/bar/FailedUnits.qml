import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// When systemd units failed: how many, and a click says which.
Button {
	id: button

	readonly property bool wanted: Units.failed.length > 0

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	icon: "alert"
	text: `${Units.failed.length}`
	ink: Theme.colors.error
	onClicked: {
		Units.check();
		list.middle = Panels.middleOf(button);
		list.show(button.QsWindow.window.screen);
	}
	onWantedChanged: {
		if (!wanted)
			list.hide();
	}

	component Line: Text {
		width: parent.width
		textFormat: Text.PlainText
		elide: Text.ElideRight
		font.family: Theme.font
	}

	Panel {
		id: list

		align: "top"
		panelWidth: Theme.u(320)

		Repeater {
			model: Units.failed

			Column {
				required property var modelData

				width: parent.width
				spacing: Theme.u(2)

				Line {
					text: modelData.unit
					color: Theme.colors.text
					font.pixelSize: Theme.fontSize
					font.weight: Theme.fontWeight
				}

				Line {
					text: `${modelData.user ? "User" : "System"} · ${modelData.description}`
					color: Theme.colors.subtext
					font.pixelSize: Theme.fontSize - Theme.u(1)
				}
			}
		}
	}
}
