import QtQuick
import qs
import qs.clipboard
import qs.ui

// The clipboard's history. The list has the keys: Enter or a click puts an
// entry back and closes, Delete removes it, and typing goes to the filter,
// where Delete is the text's again until Down.
Panel {
	id: panel

	// The newest rows shown; the rest of the history can be filtered for.
	readonly property int cap: 100
	readonly property var matches: {
		const wanted = filter.text.toLowerCase();
		return Clipboard.entries.filter(entry => `${entry.text} ${entry.subtext || ""}`.toLowerCase().includes(wanted));
	}
	readonly property var rows: matches.slice(0, cap)
	readonly property string summary: matches.length > cap ? `Newest ${cap} of ${matches.length}`
		: matches.length === 1 ? "1 entry" : `${matches.length} entries`
	// What the panel has for the list: all but the filter, the row under the list
	// and the gaps between them.
	readonly property real listRoom: room - filter.height - clear.height - Theme.u(20)

	align: Settings.corner("clipboard")

	// For tests: how many, and never what.
	onSummaryChanged: console.info("okaeri: clipboard:", summary)

	// At the newest row, wherever it was left, and with no idea of the pointer.
	onPanelOpened: {
		filter.text = "";
		list.pointer = null;
		list.currentIndex = list.count ? 0 : -1;
		list.positionViewAtBeginning();
		list.forceActiveFocus();
		Clipboard.load();
	}

	Connections {
		target: Clipboard

		function onToggleRequested() {
			panel.toggle();
		}
	}

	TextField {
		id: filter

		width: parent.width
		icon: "search"
		placeholder: "Filter"
		onAccepted: list.activate(list.currentIndex)
		Keys.onDownPressed: {
			list.forceActiveFocus();
			list.move(1);
		}
	}

	Item {
		width: parent.width
		height: list.count ? list.height : Theme.u(72)

		Keys.onPressed: event => {
			if (event.key === Qt.Key_Backspace)
				filter.text = filter.text.slice(0, -1);
			else if (event.text >= " " && event.text !== "\x7f")
				filter.text += event.text;
			else
				return;
			filter.take();
			event.accepted = true;
		}

		List {
			id: list

			// Known from the entry: the list's height comes from these and not from
			// contentHeight, which follows the height.
			function heightOf(entry) {
				return entry.picture ? Theme.u(52) : rowHeight;
			}

			// By the key and by the trash. A new model starts the list over at the
			// top: it goes back to where it was, row for row, and the next row
			// comes up under the keys and the pointer.
			function removeRow(index) {
				if (!usable(index))
					return;
				const top = indexAt(0, contentY);
				const into = contentY - itemAtIndex(top).y;
				Clipboard.remove(model[index]);
				currentIndex = Math.min(index, count - 1);
				positionViewAtIndex(top, ListView.Beginning);
				if (into > 0)
					contentY = Math.min(contentY + into, originY + contentHeight - height);
			}

			width: parent.width
			// The half row says there's more.
			height: Math.min(panel.rows.reduce((sum, entry) => sum + heightOf(entry), 0), rowHeight * 11.5, panel.listRoom)
			focus: true
			// Rows stay a good way out of sight: one that came back with a picture
			// would decode it all over again.
			cacheBuffer: Theme.u(3000)
			model: panel.rows
			delegate: ClipboardRow {}
			onActivated: (index, entry) => {
				Clipboard.restore(entry);
				panel.hide();
			}
			Keys.onUpPressed: {
				if (currentIndex > 0)
					move(-1);
				else
					filter.take();
			}
			Keys.onDeletePressed: removeRow(currentIndex)
		}

		Text {
			anchors.fill: parent
			visible: list.count === 0
			text: Clipboard.entries.length ? "Nothing matches" : "Nothing copied yet"
			horizontalAlignment: Text.AlignHCenter
			verticalAlignment: Text.AlignVCenter
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}
	}

	// This row comes up as the list gets shorter: Clear all is on the other side
	// from the rows' trash, or a second click there would take everything.
	Item {
		width: parent.width
		height: clear.height
		visible: Clipboard.entries.length > 0

		Text {
			anchors.right: parent.right
			anchors.rightMargin: Theme.u(10)
			anchors.verticalCenter: parent.verticalCenter
			visible: list.count > 0
			text: panel.summary
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
			font.features: {
				"tnum": 1
			}
		}

		Button {
			id: clear

			height: Theme.u(28)
			flat: true
			icon: "trash"
			text: "Clear all"
			ink: Theme.colors.subtext
			onClicked: Clipboard.clear()
		}
	}
}
