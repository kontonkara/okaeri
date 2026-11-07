import QtQuick
import Quickshell.Widgets
import qs

// A list to pick from, by the pointer or by the keys. `model` is an array, or
// a ScriptModel of one, of { text, subtext, icon (of Theme.icons), image (a
// source, with `icon` for one that won't load), check, more, mark (an icon at
// its end), enabled, separator }, all but `text` left out as needed; it can hold
// anything else for whoever gets activated(index, entry). A right click says
// menuAsked(index, entry). Text in it is never markup.
ListView {
	id: list

	property real rowHeight: Theme.u(38)
	// Of the pictures on its rows.
	property real iconSize: Theme.u(18)
	// Where the pointer last was in the window, null for not seen yet: set that
	// at an opening, and the row it opened on doesn't count as moved onto.
	property var pointer: null

	signal activated(int index, var entry)
	signal menuAsked(int index, var entry)

	// Row `index`. An array has a `values` too, a function.
	function entry(index) {
		const values = model?.values;
		return (typeof values === "function" ? model : values)?.[index];
	}

	function usable(index) {
		const row = entry(index);
		return !!row && !row.separator && row.enabled !== false;
	}

	// To the next row that can be picked, `by` 1 or -1.
	function move(by) {
		for (let index = currentIndex + by; index >= 0 && index < count; index += by) {
			if (usable(index)) {
				currentIndex = index;
				return;
			}
		}
	}

	function activate(index) {
		if (usable(index))
			activated(index, entry(index));
	}

	// The pointer is `at` on row `index`. Only a pointer that moved picks it: a
	// row that comes up under one at rest would take the selection from the keys.
	function follow(index, at) {
		const last = pointer;
		pointer = at;
		if (last && at !== last)
			currentIndex = index;
	}

	implicitWidth: Theme.u(280)
	implicitHeight: contentHeight
	clip: true
	boundsBehavior: Flickable.StopAtBounds
	activeFocusOnTab: true
	keyNavigationEnabled: false
	currentIndex: -1
	highlightMoveDuration: Theme.animate ? 120 : 0
	highlightResizeDuration: 0

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Down)
			move(1);
		else if (event.key === Qt.Key_Up)
			move(-1);
		else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
			activate(currentIndex);
		else
			return;
		event.accepted = true;
	}

	Glide {
		view: list
	}

	// What Enter goes by: Theme.hover is faint on black.
	highlight: Rectangle {
		radius: Math.max(0, Theme.cardRadius - Theme.u(4))
		color: Theme.pressed
	}

	delegate: Item {
		id: row

		required property var modelData
		required property int index

		readonly property bool usable: !modelData.separator && modelData.enabled !== false

		width: ListView.view.width
		height: modelData.separator ? Theme.u(9) : list.rowHeight
		opacity: modelData.enabled === false ? 0.5 : 1

		Rectangle {
			anchors.verticalCenter: parent.verticalCenter
			width: parent.width
			height: 1
			visible: !!row.modelData.separator
			color: Theme.border
		}

		Row {
			anchors.left: parent.left
			anchors.leftMargin: Theme.u(10)
			anchors.verticalCenter: parent.verticalCenter
			visible: !row.modelData.separator
			spacing: Theme.u(10)

			Icon {
				anchors.verticalCenter: parent.verticalCenter
				visible: !!row.modelData.icon && !picture.visible
				name: row.modelData.icon || ""
				size: list.iconSize
				color: Theme.colors.subtext
			}

			IconImage {
				id: picture

				anchors.verticalCenter: parent.verticalCenter
				visible: !!row.modelData.image && status !== Image.Error
				source: row.modelData.image || ""
				asynchronous: true
				implicitSize: list.iconSize
			}

			Column {
				anchors.verticalCenter: parent.verticalCenter

				Text {
					width: Math.min(implicitWidth, row.width - Theme.u(80))
					text: row.modelData.text || ""
					textFormat: Text.PlainText
					color: Theme.colors.text
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
				}

				Text {
					width: Math.min(implicitWidth, row.width - Theme.u(80))
					visible: !!row.modelData.subtext
					text: row.modelData.subtext || ""
					textFormat: Text.PlainText
					color: Theme.colors.subtext
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(2)
				}
			}
		}

		Icon {
			anchors.right: parent.right
			anchors.rightMargin: Theme.u(10)
			anchors.verticalCenter: parent.verticalCenter
			visible: !!row.modelData.check || !!row.modelData.more || !!row.modelData.mark
			name: row.modelData.check ? "check" : row.modelData.mark || "chevron"
			size: Theme.u(16)
			color: row.modelData.check ? Theme.colors.accent : Theme.colors.subtext
		}

		MouseArea {
			anchors.fill: parent
			enabled: row.usable
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onPositionChanged: event => list.follow(row.index, mapToItem(null, event.x, event.y))
			onClicked: event => {
				if (event.button === Qt.RightButton)
					list.menuAsked(row.index, row.modelData);
				else
					list.activate(row.index);
			}
		}
	}
}
