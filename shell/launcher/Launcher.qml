import QtQuick
import Quickshell.Io
import qs
import qs.ui

// The app launcher: what's typed picks from the apps and Enter launches the
// selected one. The field keeps the keys, Up and Down reach the list from it.
Panel {
	id: launcher

	// Not a binding: an app moving up for its launch would show as the panel
	// fades.
	function search() {
		list.model = Apps.search(field.text);
		list.currentIndex = 0;
		list.positionViewAtBeginning();
	}

	// The same search over apps that came or went, on the same app if it's there.
	function refresh() {
		const selected = list.model[list.currentIndex]?.entry?.id;
		search();
		list.currentIndex = Math.max(0, list.model.findIndex(row => row.entry.id === selected));
	}

	align: "center"
	panelWidth: Theme.u(520)

	onPanelOpened: {
		field.text = "";
		list.pointer = null;
		field.take();
		search();
	}

	// This also has Apps start now, and read the apps before the first opening.
	Connections {
		target: Apps

		function onKnownChanged() {
			if (launcher.shown)
				launcher.refresh();
		}
	}

	IpcHandler {
		target: "launcher"

		function toggle(): void {
			launcher.toggle();
		}
	}

	TextField {
		id: field

		width: parent.width
		focus: true
		icon: "search"
		placeholder: "Search apps"
		onTextChanged: launcher.search()
		onAccepted: list.activate(list.currentIndex)
		Keys.onUpPressed: list.move(-1)
		Keys.onDownPressed: list.move(1)
	}

	// As tall with one app as with many: on a centered panel the field would
	// move with each keystroke.
	Item {
		width: parent.width
		height: list.rowHeight * 8

		List {
			id: list

			anchors.fill: parent
			activeFocusOnTab: false
			onActivated: (index, row) => {
				// The rows still take clicks as the panel fades: a double click does.
				if (!launcher.shown)
					return;
				Apps.launch(row.entry);
				launcher.hide();
			}
		}

		Text {
			anchors.centerIn: parent
			visible: list.count === 0
			text: "No apps found"
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

	}
}
