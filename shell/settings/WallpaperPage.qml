import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.ui

// The wallpaper, on three leaves: the pictures of a folder to pick it from,
// Settings.wallpaper.folder, or where the wallpaper is, read only as they come
// into view; Wallhaven's, looked for there and fetched into the folder as one
// is picked; and how one is shown, when another takes its place, and what's on
// the desktop over it: the time, the weather, what plays, what's coming. With
// more screens than one a picture can be one screen's own, and one can be for
// light colors only. A right click on a picture has those choices at hand, and
// opening it or copying where it is.
Column {
	id: page

	readonly property real gap: Math.round(Theme.u(8))
	readonly property var own: Settings.wallpaper
	// Which leaf shows: the pictures, how they show, or Wallhaven's.
	property bool showing: false
	property bool online: false
	// Who the pictures are picked for: a screen, by its name, "*light" for all of
	// them under a light palette, "" for all of them.
	property string screen
	// The screens there are, and those with a picture of their own that aren't.
	readonly property var screens: [...new Set(Quickshell.screens.map(screen => screen.name).concat(Object.keys(own.screens)))]
	// What's picked for whoever the pictures are picked for.
	readonly property string current: screen === "*light" ? own.light : screen ? own.screens[screen] ?? "" : own.path
	// More than one to pick for: screens, or a palette that changes by the hour, or
	// a picture kept for a light one.
	readonly property bool several: screens.length > 1 || Theme.timed || own.light !== ""

	function pick(path) {
		if (screen === "*light")
			Settings.set("wallpaper", "light", path);
		else if (screen)
			Settings.set("wallpaper", "screens", Object.assign({}, own.screens, { [screen]: path }));
		else
			Settings.set("wallpaper", "path", path);
	}

	// What the others have again, for the one they're picked for.
	function drop() {
		if (screen === "*light") {
			Settings.set("wallpaper", "light", "");
			return;
		}
		const rest = Object.assign({}, own.screens);
		delete rest[screen];
		Settings.set("wallpaper", "screens", rest);
	}

	// For the search: the leaf that has `item`, and it in sight there.
	function bring(item) {
		for (let above = item; above; above = above.parent) {
			if (above === how) {
				showing = true;
				page.online = false;
				how.contentY = Math.max(0, Math.min(item.mapToItem(how.contentItem, 0, 0).y - Theme.u(16), how.contentHeight - how.height));
				return;
			}
			if (above === onlineLeaf) {
				page.online = true;
				showing = false;
				return;
			}
		}
		showing = false;
		page.online = false;
	}

	spacing: Math.round(Theme.u(10))

	Row {
		spacing: Theme.u(6)

		Button {
			height: Theme.u(30)
			flat: page.showing || page.online
			text: Tr.t("Pictures")
			onClicked: {
				page.showing = false;
				page.online = false;
			}
		}

		Button {
			height: Theme.u(30)
			flat: !page.showing
			text: Tr.t("How they show")
			onClicked: {
				page.showing = true;
				page.online = false;
			}
		}

		// Only with curl to fetch a picture by.
		Button {
			height: Theme.u(30)
			flat: !page.online
			text: Tr.t("Wallhaven")
			visible: !Env.lacks("curl")
			onClicked: {
				page.online = true;
				page.showing = false;
			}
		}
	}

	Column {
		width: parent.width
		height: parent.height - y
		visible: !page.showing && !page.online
		spacing: page.spacing

		FolderListModel {
			id: pictures

			folder: Settings.url(Settings.pictures)
			nameFilters: ["*.bmp", "*.gif", "*.jpeg", "*.jpg", "*.png", "*.webp"]
			caseSensitive: false
			sortCaseSensitive: false
			showDirs: false

			// Once they're all known: the wallpaper can be anywhere among them.
			onStatusChanged: {
				if (status === FolderListModel.Ready) {
					grid.currentIndex = indexOf(Settings.url(page.current));
					grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
				}
			}
		}

		TextField {
			width: parent.width
			icon: "image"
			placeholder: Tr.t("Folder")
			text: Settings.pictures
			keeps: true
			onAccepted: Settings.set("wallpaper", "folder", text.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
		}

		Item {
			width: parent.width
			height: whose.height
			visible: page.several

			Pick {
				id: whose

				width: parent.width - (same.visible ? same.width + Theme.u(8) : 0)
				text: Tr.t("They're for")
				subtext: page.screen && !page.current ? Tr.t("It has what the others have") : ""
				options: [{ value: "", text: Tr.t("Every screen") }].concat(page.screens.length > 1 ? page.screens.map(name => ({ value: name, text: name })) : [], [{ value: "*light", text: Tr.t("Light colors") }])
				value: page.screen
				onChosen: value => page.screen = value
			}

			Button {
				id: same

				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				height: Theme.u(30)
				visible: page.screen !== "" && page.current !== ""
				text: Tr.t("As the others")
				onClicked: page.drop()
			}
		}

		GridView {
			id: grid

			width: parent.width
			height: parent.height - y
			cellWidth: Math.floor(width / 3)
			cellHeight: Math.round(cellWidth * 9 / 16)
			model: pictures
			clip: true
			boundsBehavior: Flickable.StopAtBounds
			activeFocusOnTab: true

			Glide {
				view: grid
				notch: grid.cellHeight
			}

			Keys.onPressed: event => {
				if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
					if (currentItem)
						page.pick(currentItem.filePath);
					event.accepted = true;
				}
			}

			delegate: Item {
				id: tile

				required property int index
				required property url fileUrl
				required property string filePath

				width: grid.cellWidth
				height: grid.cellHeight

				ClippingRectangle {
					id: frame

					x: page.gap / 2
					y: page.gap / 2
					width: parent.width - page.gap
					height: parent.height - page.gap
					radius: Math.max(0, Theme.cardRadius - Theme.u(4))
					color: Theme.hover

					Image {
						anchors.fill: parent
						source: tile.fileUrl
						sourceSize: Qt.size(width, height)
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
					}

					Rectangle {
						anchors.fill: parent
						color: pointer.containsMouse ? Qt.alpha(Theme.colors.text, 0.12) : "transparent"
					}
				}

				Rectangle {
					anchors.fill: frame
					visible: tile.filePath === page.current
					radius: frame.radius
					color: "transparent"
					border.width: Math.max(2, Theme.u(2))
					border.color: Theme.colors.accent
				}

				FocusRing {
					anchors.fill: frame
					visible: grid.activeFocus && tile.index === grid.currentIndex
					cornerRadius: frame.radius
				}

				MouseArea {
					id: pointer

					anchors.fill: parent
					hoverEnabled: true
					acceptedButtons: Qt.LeftButton | Qt.RightButton
					cursorShape: Qt.PointingHandCursor
					onClicked: event => {
						grid.currentIndex = tile.index;
						if (event.button === Qt.RightButton)
							options.open(tile.filePath, tile.mapToItem(grid, event.x, event.y));
						else
							page.pick(tile.filePath);
					}
				}
			}

			// What else a picture can be, by a right click on it: over the pictures, and
			// gone with a click anywhere else or the wheel.
			Item {
				id: options

				property string path: ""
				property point at
				readonly property var rows: !path ? [] : [{ text: "For every screen", does: path => Settings.set("wallpaper", "path", path) }].concat(page.screens.length > 1 ? page.screens.map(name => ({ text: Tr.f("Only on %1", name), does: path => Settings.set("wallpaper", "screens", Object.assign({}, page.own.screens, { [name]: path })) })) : [], [
						{ text: Tr.t("With light colors"), does: path => Settings.set("wallpaper", "light", path) },
						{ text: "Open it", does: path => Env.act("open file", () => Niri.spawn(["xdg-open", path])) },
						{ text: "Copy where it is", does: path => Env.act("copy path", () => Quickshell.execDetached(["wl-copy", "--", path])) }
					])

				function open(path, point) {
					options.path = path;
					at = point;
				}

				// Closed first: what the row does changes the settings, and the rows come
				// anew with them, the one clicked too.
				function choose(row) {
					const chosen = path;
					path = "";
					row.does(chosen);
				}

				parent: grid
				anchors.fill: parent
				z: 2
				visible: path !== ""

				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.AllButtons
					onPressed: options.path = ""
					onWheel: options.path = ""
				}

				Rectangle {
					x: Math.max(0, Math.min(options.at.x, options.width - width - Theme.u(4)))
					y: Math.max(0, Math.min(options.at.y, options.height - height - Theme.u(4)))
					width: Theme.u(220)
					height: choices.height + Theme.u(12)
					radius: Theme.cardRadius
					color: Theme.panel
					border.width: 1
					border.color: Theme.border

					// A click on it isn't one elsewhere.
					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.AllButtons
					}

					Column {
						id: choices

						x: Theme.u(6)
						y: Theme.u(6)
						width: parent.width - Theme.u(12)

						Repeater {
							model: options.rows

							Button {
								required property var modelData

								width: parent.width
								height: Theme.u(32)
								flat: true
								atStart: true
								text: modelData.text
								onClicked: options.choose(modelData)
							}
						}
					}
				}
			}

			Text {
				anchors.centerIn: parent
				visible: pictures.status !== FolderListModel.Loading && pictures.count === 0
				text: Tr.t("No pictures here")
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}
		}
	}

	// Wallhaven's, looked for only when asked: a click on one fetches it into the
	// folder and puts it up for whoever the pictures are picked for.
	Column {
		id: onlineLeaf

		width: parent.width
		height: parent.height - y
		visible: page.online
		spacing: page.spacing

		TextField {
			objectName: "wallhaven-field"
			width: parent.width
			icon: "search"
			placeholder: Tr.t("Look on Wallhaven, or Enter for the most liked")
			onAccepted: Wallhaven.search(text)
		}

		Text {
			width: parent.width
			visible: text !== ""
			text: Wallhaven.looking ? Tr.t("Looking...") : Wallhaven.taking ? Tr.t("Fetching it...") : Wallhaven.trouble || (Wallhaven.asked !== "" && Wallhaven.found.length === 0 ? Tr.t("Nothing found") : "")
			color: Wallhaven.trouble ? Theme.colors.error : Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(1)
		}

		GridView {
			id: found

			width: parent.width
			height: parent.height - y
			cellWidth: Math.floor(width / 3)
			cellHeight: Math.round(cellWidth * 9 / 16)
			model: Wallhaven.found
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Glide {
				view: found
				notch: found.cellHeight
			}

			delegate: Item {
				id: result

				required property var modelData

				width: found.cellWidth
				height: found.cellHeight

				ClippingRectangle {
					x: page.gap / 2
					y: page.gap / 2
					width: parent.width - page.gap
					height: parent.height - page.gap
					radius: Math.max(0, Theme.cardRadius - Theme.u(4))
					color: Theme.hover

					Image {
						anchors.fill: parent
						source: result.modelData.thumb
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
					}

					Rectangle {
						anchors.fill: parent
						color: Wallhaven.taking === result.modelData.id ? Qt.alpha(Theme.colors.background, 0.5) : chooser.containsMouse ? Qt.alpha(Theme.colors.text, 0.12) : "transparent"
					}
				}

				MouseArea {
					id: chooser

					objectName: "result"

					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: Wallhaven.take(result.modelData, Settings.pictures, path => page.pick(path))
				}

				Tip {
					listens: false
					hovered: chooser.containsMouse
					pressed: chooser.pressed
					text: result.modelData.size
				}
			}
		}
	}

	Flickable {
		id: how

		width: parent.width
		height: parent.height - y
		visible: page.showing
		contentHeight: cards.height
		clip: true
		boundsBehavior: Flickable.StopAtBounds

		Glide {
			view: how
		}

		Column {
			id: cards

			width: parent.width
			spacing: page.spacing

			Card {
				width: parent.width
				title: Tr.t("On the screen")

				Pick {
					holds: "wallpaper.fill"
					text: Tr.t("A picture of another shape")
					subtext: ({
							crop: "Fills the screen, cut at its sides",
							fit: "Is whole, with edges beside it",
							stretch: "Is pulled to the screen's shape",
							center: "Is as large as it is, in the middle",
							tile: "Is as large as it is, over and over"
						})[page.own.fill] ?? ""
					options: [
						{ value: "crop", text: Tr.t("Cropped") },
						{ value: "fit", text: Tr.t("Fitted") },
						{ value: "stretch", text: Tr.t("Stretched") },
						{ value: "center", text: Tr.t("Centered") },
						{ value: "tile", text: Tr.t("Tiled") }
					]
					value: page.own.fill
					onChosen: value => Settings.set("wallpaper", "fill", value)
				}

				Setting {
					holds: "wallpaper.backdrop"
					text: Tr.t("Blurred behind the overview")
					checked: page.own.backdrop
					onToggled: wanted => Settings.set("wallpaper", "backdrop", wanted)
				}
			}

			Card {
				width: parent.width
				title: Tr.t("A new one")

				Pick {
					holds: "wallpaper.transition"
					text: Tr.t("The way it comes")
					options: [
						{ value: "fade", text: Tr.t("Fade") },
						{ value: "slide", text: Tr.t("Slide") },
						{ value: "wipe", text: Tr.t("Wipe") },
						{ value: "zoom", text: Tr.t("Zoom") }
					]
					value: page.own.transition
					onChosen: value => Settings.set("wallpaper", "transition", value)
				}

				Choice {
					holds: "wallpaper.fade"
					text: Tr.t("It takes")
					values: [0, 300, 500, 1000, 1500, 2000, 3000]
					value: page.own.fade
					none: Tr.t("No time")
					unit: " ms"
					onChosen: value => Settings.set("wallpaper", "fade", value)
				}

				Pick {
					holds: "wallpaper.every"
					words: "slideshow rotate cycle"
					text: Tr.t("Another every")
					subtext: Tr.t("Out of the folder, for every screen without one of its own")
					options: [
						{ value: 0, text: Tr.t("Never") },
						{ value: 5, text: "5 min" },
						{ value: 15, text: "15 min" },
						{ value: 30, text: "30 min" },
						{ value: 60, text: Tr.t("Hour") },
						{ value: 180, text: "3 hours" },
						{ value: 1440, text: Tr.t("Day") }
					]
					value: page.own.every
					onChosen: value => Settings.set("wallpaper", "every", value)
				}

				Setting {
					holds: "wallpaper.random"
					text: Tr.t("Any of them")
					subtext: Tr.t("Not the next by name")
					enabled: page.own.every > 0
					checked: page.own.random
					onToggled: wanted => Settings.set("wallpaper", "random", wanted)
				}
			}

			// What's over the wallpaper, under the windows.
			Card {
				width: parent.width
				title: Tr.t("On the desktop")

				Setting {
					holds: "desktop.clock"
					words: "widget desktop clock"
					text: Tr.t("The time")
					subtext: Tr.t("Large, with the day")
					checked: Settings.desktop.clock
					onToggled: wanted => Settings.set("desktop", "clock", wanted)
				}

				Setting {
					holds: "desktop.seconds"
					text: Tr.t("With seconds")
					visible: Settings.desktop.clock
					checked: Settings.desktop.seconds
					onToggled: wanted => Settings.set("desktop", "seconds", wanted)
				}

				Setting {
					holds: "desktop.weather"
					words: "widget desktop"
					text: Tr.t("The weather now")
					subtext: Weather.on ? Tr.t("And today's high and low") : Tr.t("Where you are goes on the Bar page, the clock's")
					checked: Settings.desktop.weather
					onToggled: wanted => Settings.set("desktop", "weather", wanted)
				}

				Setting {
					holds: "desktop.media"
					words: "widget desktop player music"
					text: Tr.t("What plays")
					subtext: Tr.t("With its buttons, while a player's open")
					checked: Settings.desktop.media
					onToggled: wanted => Settings.set("desktop", "media", wanted)
				}

				Setting {
					holds: "desktop.events"
					words: "widget desktop calendar agenda"
					text: Tr.t("What's coming")
					subtext: Events.on ? Tr.t("Today's and tomorrow's, from the calendars") : Tr.t("Calendars go on the Bar page, the clock's")
					checked: Settings.desktop.events
					onToggled: wanted => Settings.set("desktop", "events", wanted)
				}

				Pick {
					holds: "desktop.position"
					text: Tr.t("Where they are")
					valueWidth: Theme.u(150)
					options: [
						{ value: "top-left", text: Tr.t("Top left") },
						{ value: "top-right", text: Tr.t("Top right") },
						{ value: "center", text: Tr.t("In the middle") },
						{ value: "bottom-left", text: Tr.t("Bottom left") },
						{ value: "bottom-right", text: Tr.t("Bottom right") }
					]
					value: Settings.desktop.position
					onChosen: value => Settings.set("desktop", "position", value)
				}
			}
		}
	}
}
