import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs
import qs.ui

// The pictures of a folder, to pick the wallpaper from: Settings.wallpaper.folder,
// or where the wallpaper is. They're only read as they come into view.
Column {
	id: page

	readonly property string folder: Settings.wallpaper.folder || Settings.wallpaper.path.replace(/\/[^/]*$/, "") || `${Quickshell.env("HOME")}/Pictures`
	readonly property real gap: Math.round(Theme.u(8))

	function pick(path) {
		Settings.set("wallpaper", "path", path);
	}

	spacing: Math.round(Theme.u(10))

	FolderListModel {
		id: pictures

		folder: Settings.url(page.folder)
		nameFilters: ["*.bmp", "*.gif", "*.jpeg", "*.jpg", "*.png", "*.webp"]
		caseSensitive: false
		sortCaseSensitive: false
		showDirs: false

		// Once they're all known: the wallpaper can be anywhere among them.
		onStatusChanged: {
			if (status === FolderListModel.Ready) {
				grid.currentIndex = indexOf(Settings.url(Settings.wallpaper.path));
				grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
			}
		}
	}

	TextField {
		width: parent.width
		icon: "image"
		placeholder: "Folder"
		text: page.folder
		onAccepted: Settings.set("wallpaper", "folder", text.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
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
				visible: tile.filePath === Settings.wallpaper.path
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
				cursorShape: Qt.PointingHandCursor
				onClicked: {
					grid.currentIndex = tile.index;
					page.pick(tile.filePath);
				}
			}
		}

		Text {
			anchors.centerIn: parent
			visible: pictures.status !== FolderListModel.Loading && pictures.count === 0
			text: "No pictures here"
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}
	}
}
