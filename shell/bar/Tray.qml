import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.ui

// The apps' icons, but for those Settings.tray.hidden names by id, and the quiet
// ones unless Settings.tray.passive: on the bar, or with Settings.tray.drawer
// behind a button that shows them in a panel, all but those Settings.tray.pinned
// keeps on the bar. One under another on a bar at a side.
Grid {
	id: tray

	readonly property var shown: SystemTray.items.values.filter(item => (Settings.tray.passive || item.status !== Status.Passive) && !Settings.tray.hidden.includes(item.id))
	readonly property var drawn: Settings.tray.drawer ? shown.filter(item => !Settings.tray.pinned.includes(item.id)) : []
	readonly property bool wanted: shown.length > 0

	columns: Settings.barSide ? 1 : 1000
	horizontalItemAlignment: Grid.AlignHCenter
	verticalItemAlignment: Grid.AlignVCenter
	spacing: Theme.u(4)

	TrayMenu {
		id: menu
	}

	TrayDrawer {
		id: drawer

		items: tray.drawn
		trayMenu: menu
	}

	BarButton {
		id: opener

		visible: tray.drawn.length > 0
		icon: "tray"
		tip: "Tray"
		onClicked: drawer.showUnder(opener)
	}

	Repeater {
		model: ScriptModel {
			values: tray.shown.filter(item => !tray.drawn.includes(item))
		}

		TrayIcon {
			trayMenu: menu
		}
	}
}
