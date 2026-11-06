import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// The picture behind everything on each screen, Settings.wallpaper.path, cropped
// to fill it. A new one fades in over the last. With Settings.wallpaper.backdrop
// also a blurred one for behind the overview.
Scope {
	id: wallpaper

	Variants {
		model: Settings.wallpaper.path && Settings.wallpaper.backdrop ? Quickshell.screens : []

		Backdrop {
			source: Settings.url(Settings.wallpaper.path)
		}
	}

	Variants {
		model: Settings.wallpaper.path ? Quickshell.screens : []

		PanelWindow {
			id: window

			required property var modelData

			readonly property string path: Settings.wallpaper.path
			// The two take turns: one shows, the other is where the next is read.
			property Image shown: first
			readonly property Image next: shown === first ? second : first

			function load() {
				if (!path)
					return;
				next.source = Settings.url(path);
				if (next.status === Image.Ready)
					reveal();
			}

			function reveal() {
				shown = next;
				fade.target = shown;
				fade.restart();
			}

			onPathChanged: load()
			Component.onCompleted: load()

			screen: modelData
			anchors {
				top: true
				left: true
				right: true
				bottom: true
			}
			color: Theme.colors.background
			exclusionMode: ExclusionMode.Ignore
			WlrLayershell.layer: WlrLayer.Background
			WlrLayershell.namespace: "okaeri-wallpaper"
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

			component Picture: Image {
				id: picture

				anchors.fill: parent
				asynchronous: true
				cache: false
				fillMode: Image.PreserveAspectCrop
				sourceSize: Qt.size(window.width * window.modelData.devicePixelRatio, window.height * window.modelData.devicePixelRatio)
				z: window.shown === picture ? 1 : 0

				onStatusChanged: {
					if (status === Image.Ready && window.next === picture)
						window.reveal();
				}
			}

			Picture {
				id: first
			}

			Picture {
				id: second
			}

			NumberAnimation {
				id: fade

				property: "opacity"
				from: 0
				to: 1
				duration: Theme.animate ? Settings.wallpaper.fade : 0
				easing.type: Easing.InOutQuad
				// What's under it is seen no more, and needn't take the memory.
				onFinished: window.next.source = ""
			}
		}
	}
}
