import QtQuick
import Quickshell
import qs
import qs.ui

// The apps' icons in a panel under the button that opens it.
Panel {
	id: drawer

	property var items: []
	property var trayMenu

	function showUnder(under) {
		middle = Panels.middleOf(under);
		show(under.QsWindow.window.screen);
	}

	align: "top"
	padding: Theme.u(6)
	panelWidth: Math.min(Math.max(items.length, 1), 6) * Theme.u(34) - Theme.u(6) + padding * 2

	// The last one went away.
	onItemsChanged: {
		if (shown && !items.length)
			hide();
	}

	Flow {
		width: parent.width
		spacing: Theme.u(6)

		Repeater {
			model: ScriptModel {
				values: drawer.items
			}

			TrayIcon {
				trayMenu: drawer.trayMenu
				onDone: drawer.hide()
			}
		}
	}
}
