import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// What's in Settings, to change in place, a page at a time. A change stays over
// what the config says, and the button under the pages goes back to that. It's a
// window, not a panel: the compositor's keys go to it and not to what's under it,
// and it stays while what it changes is looked at.
FloatingWindow {
	id: window

	readonly property var pages: [
		{ text: "Bar", icon: "bar", page: barPage },
		{ text: "Tray", icon: "tray", page: trayPage },
		{ text: "Launcher", icon: "search", page: launcherPage },
		{ text: "Wallpaper", icon: "image", page: wallpaperPage },
		{ text: "Session", icon: "lock", page: sessionPage }
	]
	property int page: 0
	// One size: that's also what makes niri open it floating, with no rule for it.
	readonly property size fixed: Qt.size(Math.round(Theme.u(760)), Math.round(Math.min(Theme.u(564), (Niri.focusedScreen?.height ?? Infinity) - Theme.below - Theme.edge)))

	// Opened anew, so one left on another workspace comes here, with the focus.
	function show() {
		visible = false;
		visible = true;
	}

	function toggle() {
		if (visible)
			visible = false;
		else
			show();
	}

	title: "Settings"
	visible: false
	implicitWidth: fixed.width
	implicitHeight: fixed.height
	minimumSize: fixed
	maximumSize: fixed
	color: Theme.panel
	BackgroundEffect.blurRegion: Theme.blur ? glass : null

	Region {
		id: glass

		item: window.contentItem
		radius: Theme.cardRadius
	}

	Connections {
		target: Settings

		function onAsked() {
			window.show();
		}
	}

	IpcHandler {
		target: "settings"

		function toggle(): void {
			window.toggle();
		}
	}

	Component {
		id: barPage

		BarPage {}
	}

	Component {
		id: trayPage

		TrayPage {}
	}

	Component {
		id: launcherPage

		LauncherPage {}
	}

	Component {
		id: wallpaperPage

		WallpaperPage {}
	}

	Component {
		id: sessionPage

		SessionPage {}
	}

	Loader {
		anchors.fill: parent
		anchors.margins: Math.round(Theme.u(12))
		active: window.visible
		focus: true

		sourceComponent: FocusScope {
			focus: true

			Keys.onEscapePressed: window.visible = false

			Column {
				id: menu

				width: Theme.u(170)
				spacing: Theme.u(4)

				Repeater {
					model: window.pages

					Button {
						required property int index
						required property var modelData

						width: parent.width
						atStart: true
						pad: Theme.u(10)
						flat: index !== window.page
						icon: modelData.icon
						text: modelData.text
						onClicked: window.page = index
					}
				}
			}

			Button {
				anchors.bottom: parent.bottom
				width: menu.width
				enabled: Object.keys(Settings.own).length > 0
				atStart: true
				pad: Theme.u(10)
				flat: true
				text: "Back to the config"
				onClicked: Settings.reset()
			}

			Loader {
				x: menu.width + Math.round(Theme.u(12))
				width: parent.width - x
				height: parent.height
				sourceComponent: window.pages[window.page].page
			}
		}
	}
}
