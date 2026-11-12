import QtQuick
import Quickshell.Widgets
import qs
import qs.services
import qs.ui

// An app's icon. A click activates it, or opens its menu when that's all it
// has; a right click opens the menu, in okaeri's look. `done` says the app got
// the click.
BarButton {
	id: entry

	required property var modelData
	property var trayMenu

	signal done

	takesWheel: true
	tip: modelData.tooltipTitle || modelData.title || modelData.id
	onClicked: {
		if (modelData.onlyMenu) {
			trayMenu.showFor(modelData, entry);
		} else {
			Env.act("tray activate", () => modelData.activate());
			done();
		}
	}
	onRightClicked: {
		if (modelData.hasMenu)
			trayMenu.showFor(modelData, entry);
	}
	onMiddleClicked: {
		Env.act("tray secondary activate", () => modelData.secondaryActivate());
		done();
	}
	onScrolled: steps => Env.act(`tray scroll ${steps}`, () => modelData.scroll(steps, false))

	IconImage {
		anchors.verticalCenter: parent.verticalCenter
		source: entry.modelData.icon
		implicitSize: Theme.barIcon
	}
}
