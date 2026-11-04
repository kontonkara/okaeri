import QtQuick
import Quickshell.Widgets
import qs

// A list to pick from, by the pointer or by the keys. `model` is an array of
// { text, subtext, icon (of Theme.icons), image (a source), check, more,
// enabled, separator }, all but `text` left out as needed; it can hold
// anything else for whoever gets activated(index, entry).
ListView {
	id: list

	readonly property real rowHeight: Theme.u(38)

	signal activated(int index, var entry)

	function usable(index) {
		const entry = model[index];
		return !!entry && !entry.separator && entry.enabled !== false;
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
			activated(index, model[index]);
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

	highlight: Rectangle {
		radius: Math.max(0, Theme.cardRadius - Theme.u(4))
		color: Theme.hover
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
				visible: !!row.modelData.icon
				name: row.modelData.icon || ""
				color: Theme.colors.subtext
			}

			IconImage {
				anchors.verticalCenter: parent.verticalCenter
				visible: !!row.modelData.image
				source: row.modelData.image || ""
				implicitSize: Theme.u(18)
			}

			Column {
				anchors.verticalCenter: parent.verticalCenter

				Text {
					width: Math.min(implicitWidth, row.width - Theme.u(80))
					text: row.modelData.text || ""
					color: Theme.colors.text
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
				}

				Text {
					width: Math.min(implicitWidth, row.width - Theme.u(80))
					visible: !!row.modelData.subtext
					text: row.modelData.subtext || ""
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
			visible: !!row.modelData.check || !!row.modelData.more
			name: row.modelData.check ? "check" : "chevron"
			size: Theme.u(16)
			color: row.modelData.check ? Theme.colors.accent : Theme.colors.subtext
		}

		MouseArea {
			anchors.fill: parent
			enabled: row.usable
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onEntered: list.currentIndex = row.index
			onClicked: list.activate(row.index)
		}
	}
}
