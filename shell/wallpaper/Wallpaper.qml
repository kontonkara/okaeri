import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// The picture behind everything on each screen: Settings.wallpaper.path, or the
// screen's own in Settings.wallpaper.screens, by its name, or `light` under a
// light palette. It fills the screen as `fill` says: "crop", "fit", "stretch",
// "center" or "tile". A new one comes over the last as `transition` says, "fade",
// "slide", "wipe" or "zoom", in `fade` ms. With `every`, minutes, another of the
// folder's takes its place by itself, the next by name or any with `random`, and
// `okaeri wallpaper next` does that by hand. With `backdrop` there's also a
// blurred one for behind the overview.
Scope {
	id: wallpaper

	readonly property var own: Settings.wallpaper
	readonly property var fills: ({
			crop: Image.PreserveAspectCrop,
			fit: Image.PreserveAspectFit,
			stretch: Image.Stretch,
			center: Image.Pad,
			tile: Image.Tile
		})
	// How far along the folder the next one is, once the folder is read: 0 for
	// any of them.
	property int stepping: 0
	property bool wanted: false
	// The folder is being read for that, or was a moment ago.
	property bool reading: false

	// The picture of a screen: its own, the one for a light palette while that's
	// on, or everyone's.
	function pathOn(screen) {
		return own.screens[screen.name] || (Theme.light && own.light) || own.path;
	}

	// Another of the folder's for everyone: `by` along it, by name, round to the
	// first again, or any other with 0. The folder is read for it first.
	function turn(by) {
		stepping = by;
		wanted = true;
		reading = true;
		choose();
	}

	function choose() {
		const folder = lister.item;
		if (!wanted || !folder || folder.status !== FolderListModel.Ready)
			return;
		wanted = false;
		// Not at once: with nothing else wanting the folder, it goes with this.
		Qt.callLater(() => wallpaper.reading = false);
		if (folder.count === 0)
			return;
		const at = folder.indexOf(Settings.url(own.path));
		let to = ((at + stepping) % folder.count + folder.count) % folder.count;
		if (stepping === 0 && folder.count > 1) {
			do
				to = Math.floor(Math.random() * folder.count);
			while (to === at);
		}
		const next = folder.get(to, "filePath");
		if (next !== own.path)
			Settings.set("wallpaper", "path", next);
	}

	// The folder's pictures, read only while one of them is to be next.
	LazyLoader {
		id: lister

		active: wallpaper.reading || wallpaper.own.every > 0

		FolderListModel {
			folder: Settings.url(Settings.pictures)
			nameFilters: ["*.bmp", "*.gif", "*.jpeg", "*.jpg", "*.png", "*.webp"]
			caseSensitive: false
			sortCaseSensitive: false
			showDirs: false
			onStatusChanged: wallpaper.choose()
		}
	}

	Timer {
		interval: Math.max(1, wallpaper.own.every) * 60000
		running: wallpaper.own.every > 0
		repeat: true
		onTriggered: wallpaper.turn(wallpaper.own.random ? 0 : 1)
	}

	IpcHandler {
		target: "wallpaper"

		function next(): void {
			wallpaper.turn(1);
		}

		function previous(): void {
			wallpaper.turn(-1);
		}

		function random(): void {
			wallpaper.turn(0);
		}
	}

	Variants {
		model: wallpaper.own.backdrop ? Quickshell.screens.filter(screen => wallpaper.pathOn(screen)) : []

		Backdrop {
			source: Settings.url(wallpaper.pathOn(modelData))
		}
	}

	Variants {
		model: Quickshell.screens.filter(screen => wallpaper.pathOn(screen))

		PanelWindow {
			id: window

			required property var modelData

			readonly property string path: wallpaper.pathOn(modelData)
			// The two take turns: one shows, the other is where the next is read.
			property Item shown: first
			readonly property Item next: shown === first ? second : first

			function load() {
				if (!path)
					return;
				next.source = Settings.url(path);
				if (next.status === Image.Ready)
					reveal();
			}

			function reveal() {
				shown = next;
				arriving.kind = Theme.animate && wallpaper.own.fade > 0 ? wallpaper.own.transition : "";
				arriving.restart();
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

			// A picture in a frame that can show less than all of it, from the left,
			// and stand aside to the right, for the ways a new one comes.
			component Picture: Item {
				id: picture

				property alias source: image.source
				readonly property alias status: image.status
				property real uncovered: 1
				property real aside: 0
				// Scaled as it's read, but for the ways that show it as large as it is.
				readonly property bool sized: !["center", "tile"].includes(wallpaper.own.fill)

				x: Math.round(window.width * aside)
				width: Math.round(window.width * uncovered)
				height: window.height
				clip: true
				z: window.shown === picture ? 1 : 0

				Image {
					id: image

					width: window.width
					height: window.height
					asynchronous: true
					cache: false
					fillMode: wallpaper.fills[wallpaper.own.fill] ?? Image.PreserveAspectCrop
					sourceSize: picture.sized ? Qt.size(window.width * window.modelData.devicePixelRatio, window.height * window.modelData.devicePixelRatio) : undefined

					onStatusChanged: {
						if (status === Image.Ready && window.next === picture)
							window.reveal();
					}
				}
			}

			Picture {
				id: first
			}

			Picture {
				id: second
			}

			// The new one from nothing to all of it, in the way that's `kind`: with
			// none it's there at once.
			ParallelAnimation {
				id: arriving

				property string kind
				readonly property int time: kind ? wallpaper.own.fade : 0

				// What's under it is seen no more, and needn't take the memory.
				onFinished: window.next.source = ""

				NumberAnimation {
					target: window.shown
					property: "opacity"
					from: arriving.kind === "slide" || arriving.kind === "wipe" ? 1 : 0
					to: 1
					duration: arriving.time
					easing.type: Easing.InOutQuad
				}

				NumberAnimation {
					target: window.shown
					property: "aside"
					from: arriving.kind === "slide" ? 1 : 0
					to: 0
					duration: arriving.time
					easing.type: Easing.OutCubic
				}

				NumberAnimation {
					target: window.shown
					property: "uncovered"
					from: arriving.kind === "wipe" ? 0 : 1
					to: 1
					duration: arriving.time
					easing.type: Easing.InOutQuad
				}

				NumberAnimation {
					target: window.shown
					property: "scale"
					from: arriving.kind === "zoom" ? 1.08 : 1
					to: 1
					duration: arriving.time
					easing.type: Easing.OutCubic
				}
			}
		}
	}
}
