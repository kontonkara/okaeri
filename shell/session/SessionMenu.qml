import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.ui

// Lock, log out, reboot and the rest. What ends the session or takes a while to
// come back from counts down first, to take a wrong key back: Escape does, and
// Enter doesn't wait. Locking and suspending are undone by a key, and don't.
Panel {
	id: menu

	// The row counting down, and its seconds left.
	property var pending: null
	property int left: 0

	function pick(row) {
		left = row.waits ? Settings.session.countdown : 0;
		if (left > 0) {
			pending = row;
			waiting.forceActiveFocus();
		} else {
			run(row);
		}
	}

	function cancel() {
		pending = null;
		list.forceActiveFocus();
	}

	function run(row) {
		hide();
		Session.run(row.action);
	}

	align: "center"
	panelWidth: Theme.u(320)

	onPanelOpened: {
		Session.check();
		list.pointer = null;
		list.currentIndex = 0;
		list.forceActiveFocus();
	}
	onPanelClosed: pending = null

	Connections {
		target: Session

		function onAsked(row) {
			menu.show();
			menu.pick(row);
		}

		function onMenuWanted() {
			menu.show();
		}
	}

	IpcHandler {
		target: "session"

		function toggle(): void {
			menu.toggle();
		}
	}

	Timer {
		interval: 1000
		repeat: true
		running: !!menu.pending
		onTriggered: {
			menu.left -= 1;
			if (menu.left <= 0)
				menu.run(menu.pending);
		}
	}

	List {
		id: list

		width: parent.width
		visible: !menu.pending
		focus: true
		model: Session.actions
		onActivated: (index, row) => {
			// The rows still take clicks as the panel fades.
			if (menu.shown)
				menu.pick(row);
		}
	}

	Column {
		id: waiting

		width: parent.width
		visible: !!menu.pending
		spacing: Theme.u(12)

		// A key still held from the list isn't a second press.
		Keys.onPressed: event => {
			if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
				return;
			if (!event.isAutoRepeat)
				menu.run(menu.pending);
			event.accepted = true;
		}
		Keys.onEscapePressed: menu.cancel()

		Text {
			width: parent.width
			text: menu.pending ? `${menu.pending.doing} in ${menu.left} s` : ""
			color: Theme.colors.text
			horizontalAlignment: Text.AlignHCenter
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
			font.weight: Theme.fontWeight
		}

		Slider {
			width: parent.width
			value: menu.left / Math.max(1, Settings.session.countdown)
			interactive: false
		}

		Row {
			anchors.horizontalCenter: parent.horizontalCenter
			spacing: Theme.u(8)

			Button {
				text: "Cancel"
				onClicked: menu.cancel()
			}

			Button {
				filled: true
				text: "Now"
				onClicked: menu.run(menu.pending)
			}
		}
	}
}
