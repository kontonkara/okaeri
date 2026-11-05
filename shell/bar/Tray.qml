import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.ui

// The apps' icons, but for those Settings.tray.hidden names by id: on the bar,
// or with Settings.tray.drawer behind a button that shows them in a panel.
Row {
	id: tray

	readonly property var shown: SystemTray.items.values.filter(item => item.status !== Status.Passive && !Settings.tray.hidden.includes(item.id))

	spacing: Theme.u(4)

	TrayMenu {
		id: menu
	}

	TrayDrawer {
		id: drawer

		items: tray.shown
		trayMenu: menu
	}

	Button {
		id: opener

		anchors.verticalCenter: parent.verticalCenter
		height: Theme.u(28)
		visible: Settings.tray.drawer && tray.shown.length > 0
		flat: true
		activeFocusOnTab: false
		icon: "tray"
		iconSize: Theme.barIcon
		onClicked: drawer.showUnder(opener)
	}

	Repeater {
		model: ScriptModel {
			values: Settings.tray.drawer ? [] : tray.shown
		}

		TrayIcon {
			anchors.verticalCenter: parent.verticalCenter
			trayMenu: menu
		}
	}
}
