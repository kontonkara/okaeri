import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.services
import qs.ui

// The apps' icons. A click activates one, or opens its menu when that's all
// it has; a right click opens the menu, in okaeri's look.
Row {
	id: tray

	spacing: Theme.u(2)

	TrayMenu {
		id: menu
	}

	Repeater {
		model: SystemTray.items

		Button {
			id: entry

			required property var modelData

			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(28)
			visible: modelData.status !== Status.Passive
			flat: true
			activeFocusOnTab: false
			onClicked: {
				if (modelData.onlyMenu)
					menu.showFor(modelData, entry);
				else
					Env.act("tray activate", () => modelData.activate());
			}
			onRightClicked: {
				if (modelData.hasMenu)
					menu.showFor(modelData, entry);
			}
			onMiddleClicked: Env.act("tray secondary activate", () => modelData.secondaryActivate())
			onScrolled: steps => Env.act(`tray scroll ${steps}`, () => modelData.scroll(steps, false))

			IconImage {
				anchors.verticalCenter: parent.verticalCenter
				source: entry.modelData.icon
				implicitSize: Theme.u(18)
			}
		}
	}
}
