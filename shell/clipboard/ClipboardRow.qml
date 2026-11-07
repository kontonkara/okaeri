import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.clipboard
import qs.ui

// An entry of the history, for List's `delegate`: what's copied can look like
// markup, and here it stays plain text. A picture is decoded to a file for its
// preview, and the file goes once the preview has what it needs, or the row
// does. It's the row's own: rows come and go as the filter changes.
Item {
	id: row

	required property var modelData
	required property int index

	readonly property var list: ListView.view
	readonly property bool picture: !!modelData.picture
	readonly property bool pinned: !!modelData.pinned
	// Where its picture is. A pinned one's has it for good.
	readonly property string file: pinned ? modelData.file : `${Clipboard.pictures}/${modelData.id}-${Date.now()}`

	width: list.width
	height: list.heightOf(modelData)

	Component.onDestruction: {
		if (picture && !pinned)
			Clipboard.discard(file);
	}

	// Only on a row with a picture: most have none, and rows are made as the list
	// moves.
	Loader {
		id: preview

		x: Theme.u(4)
		anchors.verticalCenter: parent.verticalCenter
		width: Theme.u(64)
		height: Theme.u(44)
		active: row.picture

		sourceComponent: ClippingRectangle {
			radius: Math.max(0, Theme.cardRadius - Theme.u(8))
			color: Theme.surface

			Process {
				running: !row.pinned
				command: ["sh", "-c", 'mkdir -p "${3%/*}" && cliphist -db-path "$1" decode "$2" >"$3"', "sh", Clipboard.database, row.modelData.id, row.file]
				onExited: code => {
					if (code === 0)
						image.source = `file://${row.file}`;
				}
			}

			Image {
				id: image

				anchors.fill: parent
				asynchronous: true
				cache: false
				source: row.pinned ? `file://${row.file}` : ""
				fillMode: Image.PreserveAspectCrop
				// Not by the theme's scale: a new size would read the file again.
				sourceSize: Qt.size(256, 256)
				onStatusChanged: {
					if (!row.pinned && (status === Image.Ready || status === Image.Error))
						Quickshell.execDetached(["rm", "-f", "--", row.file]);
				}
			}

			Icon {
				anchors.centerIn: parent
				visible: image.status === Image.Error
				name: "clipboard"
				color: Theme.colors.subtext
			}
		}
	}

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		// Only when it moved: a row that comes to a resting pointer isn't picked,
		// and neither is the one a panel opened under it.
		onPositionChanged: event => row.list.follow(row.index, mapToItem(null, event.x, event.y))
		onClicked: event => {
			row.list.shiftHeld = !!(event.modifiers & Qt.ShiftModifier);
			row.list.activate(row.index);
			row.list.shiftHeld = false;
		}
	}

	Column {
		anchors.left: row.picture ? preview.right : parent.left
		anchors.leftMargin: Theme.u(10)
		anchors.right: pin.left
		anchors.rightMargin: Theme.u(6)
		anchors.verticalCenter: parent.verticalCenter

		Text {
			width: parent.width
			text: row.modelData.text
			textFormat: Text.PlainText
			color: Theme.colors.text
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Text {
			width: parent.width
			visible: !!row.modelData.subtext
			text: row.modelData.subtext || ""
			textFormat: Text.PlainText
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	Button {
		id: pin

		anchors.right: row.pinned ? parent.right : remove.left
		anchors.rightMargin: row.pinned ? Theme.u(5) : 0
		anchors.verticalCenter: parent.verticalCenter
		height: Theme.u(28)
		visible: row.pinned || row.ListView.isCurrentItem
		flat: true
		activeFocusOnTab: false
		icon: "pin"
		ink: row.pinned ? Theme.colors.accent : Theme.colors.subtext
		onClicked: row.list.togglePin(row.index)
	}

	Button {
		id: remove

		anchors.right: parent.right
		anchors.rightMargin: Theme.u(5)
		anchors.verticalCenter: parent.verticalCenter
		height: Theme.u(28)
		visible: !row.pinned && row.ListView.isCurrentItem
		flat: true
		activeFocusOnTab: false
		icon: "trash"
		ink: Theme.colors.subtext
		onClicked: row.list.removeRow(row.index)
	}
}
