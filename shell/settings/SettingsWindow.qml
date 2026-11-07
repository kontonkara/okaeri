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
		{ text: "Control center", icon: "sliders", page: controlPage },
		{ text: "Launcher", icon: "search", page: launcherPage },
		{ text: "Clipboard", icon: "clipboard", page: clipboardPage },
		{ text: "Notifications", icon: "bell", page: notificationsPage },
		{ text: "Sounds", icon: "volume", page: soundsPage },
		{ text: "Wallpaper", icon: "image", page: wallpaperPage },
		{ text: "Look", icon: "eye", page: lookPage },
		{ text: "Session", icon: "lock", page: sessionPage }
	]
	property int page: 0
	// One size: that's also what makes niri open it floating, with no rule for it.
	readonly property size fixed: Qt.size(Math.round(Theme.u(760)), Math.round(Math.min(Theme.u(564), (Niri.focusedScreen?.height ?? Infinity) - Theme.below - Theme.edge)))

	// Opened anew, so one left on another workspace comes here, with the focus.
	function show() {
		visible = false;
		fade.stop();
		veil.opacity = Theme.blur && Theme.realBlur ? 1 : 0;
		visible = true;
		opening.restart();
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
	// The fill is on an item: a window that was solid when it first showed stays so.
	color: "transparent"
	// Asked for as it shows: asked for while it's hidden, it's lost once it has shown
	// without.
	BackgroundEffect.blurRegion: Theme.blur && visible ? glass : null

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

		// For tests: how much of the veil is there.
		function veiled(): real {
			return veil.opacity;
		}
	}

	Rectangle {
		anchors.fill: parent
		color: Theme.panel
	}

	// niri can't blur what's under a window while it opens, only the wallpaper: as
	// that ended the blur would come in at once. Until then it's solid, and then
	// it goes clear.
	Rectangle {
		id: veil

		anchors.fill: parent
		visible: opacity > 0
		color: Theme.colors.background
		opacity: 0
	}

	// A little longer than niri takes by default, or with the animation changed.
	Timer {
		id: opening

		interval: 300
		onTriggered: fade.restart()
	}

	NumberAnimation {
		id: fade

		target: veil
		property: "opacity"
		to: 0
		duration: Theme.animate ? 200 : 0
		easing.type: Easing.OutCubic
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
		id: controlPage

		ControlPage {}
	}

	Component {
		id: launcherPage

		LauncherPage {}
	}

	Component {
		id: clipboardPage

		ClipboardPage {}
	}

	Component {
		id: notificationsPage

		NotificationsPage {}
	}

	Component {
		id: soundsPage

		SoundsPage {}
	}

	Component {
		id: lookPage

		LookPage {}
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
				enabled: Object.keys(Settings.own).length + Object.keys(Theme.own).length > 0
				atStart: true
				pad: Theme.u(10)
				flat: true
				text: "Back to the config"
				onClicked: {
					Settings.reset();
					Theme.reset();
				}
			}

			Loader {
				id: content

				x: menu.width + Math.round(Theme.u(12))
				width: parent.width - x
				height: parent.height
				sourceComponent: window.pages[window.page].page
				transform: Translate {
					id: slide
				}
				onLoaded: {
					if (Theme.animate)
						appear.restart();
				}
			}

			// A new page comes up a little, out of nothing.
			ParallelAnimation {
				id: appear

				NumberAnimation {
					target: content
					property: "opacity"
					from: 0
					to: 1
					duration: 140
					easing.type: Easing.OutCubic
				}

				NumberAnimation {
					target: slide
					property: "y"
					from: Theme.u(8)
					to: 0
					duration: 180
					easing.type: Easing.OutCubic
				}
			}
		}
	}
}
