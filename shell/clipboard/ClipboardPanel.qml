import QtQuick
import qs
import qs.clipboard
import qs.services
import qs.ui

// The clipboard's history. The list has the keys: Enter or a click puts an
// entry back and closes, with Shift pastes it too, or the other way round by the
// settings, Ctrl+P pins it, Delete removes it, Ctrl+T leaves only text and Ctrl+I
// only pictures, as the two buttons do, and typing goes to the filter, where
// Delete is the text's again until Down. Right or a right click shows the entry
// whole, with what can be done with it. The button before those pauses the
// history, and plays it on.
Panel {
	id: panel

	// The newest rows shown; the rest of the history can be filtered for.
	readonly property int cap: Settings.clipboard.rows
	// Only "text" or only "picture", "" for both.
	property string kind: ""
	// The entry shown whole, in the list's place, null for the list.
	property var looked: null
	readonly property var matches: {
		const wanted = filter.text.toLowerCase();
		return Clipboard.shown.filter(entry => (!kind || !!entry.picture === (kind === "picture")) && `${entry.text} ${entry.subtext || ""}`.toLowerCase().includes(wanted));
	}
	readonly property var rows: matches.slice(0, cap)
	readonly property string summary: matches.length > cap ? `Newest ${cap} of ${matches.length}`
		: matches.length === 1 ? "1 entry" : `${matches.length} entries`
	// What the panel has for the list: all but the filter, the row under the list,
	// the line that says it's paused, and the gaps between them.
	readonly property real listRoom: room - filter.height - clear.height - Theme.u(20) - (pausedLine.visible ? pausedLine.height + Math.round(Theme.u(10)) : 0)

	function pick(entry, shifted) {
		Clipboard.restore(entry);
		if (shifted !== Settings.clipboard.paste)
			Clipboard.paste();
		panel.hide();
	}

	function look(entry) {
		looked = entry;
	}

	// Back to the list, at the row it was on.
	function unlook() {
		looked = null;
		list.forceActiveFocus();
	}

	// On the row that has the keys, from the filter too.
	function pinKey(event) {
		if (!(event.modifiers & Qt.ControlModifier))
			return;
		if (event.key === Qt.Key_P)
			list.togglePin(list.currentIndex);
		else if (event.key === Qt.Key_T)
			kind = kind === "text" ? "" : "text";
		else if (event.key === Qt.Key_I)
			kind = kind === "picture" ? "" : "picture";
		else
			return;
		event.accepted = true;
	}

	align: Settings.corner("clipboard")
	escapes: () => {
		if (!looked)
			return false;
		unlook();
		return true;
	}

	// For tests: how many, and never what.
	onSummaryChanged: console.info("okaeri: clipboard:", summary)

	// At the newest row, wherever it was left, and with no idea of the pointer.
	onPanelOpened: {
		filter.text = "";
		looked = null;
		kind = "";
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

	component Kind: Button {
		required property string shows

		height: filter.height
		flat: panel.kind !== shows
		activeFocusOnTab: false
		onClicked: panel.kind = panel.kind === shows ? "" : shows
	}

	Row {
		width: parent.width
		spacing: Theme.u(6)

		TextField {
			id: filter

			width: parent.width - (height + parent.spacing) * 3
			icon: "search"
			placeholder: "Filter"
			shifted: true
			onAccepted: list.activate(list.currentIndex)
			onShiftAccepted: panel.pick(list.entry(list.currentIndex), true)
			Keys.onDownPressed: {
				list.forceActiveFocus();
				list.move(1);
			}
			Keys.onPressed: event => panel.pinKey(event)
		}

		// Before the kinds, which stay where they were.
		Button {
			height: filter.height
			flat: !Clipboard.paused
			icon: Clipboard.paused ? "play" : "pause"
			tip: Clipboard.paused ? "Keep what's copied again" : "Keep nothing copied for now"
			activeFocusOnTab: false
			onClicked: Clipboard.togglePause()
		}

		Kind {
			icon: "text"
			shows: "text"
			tip: "Only text · Ctrl+T"
		}

		Kind {
			icon: "image"
			shows: "picture"
			tip: "Only pictures · Ctrl+I"
		}
	}

	Text {
		id: pausedLine

		width: parent.width
		visible: Clipboard.paused
		text: "Paused: nothing copied is kept"
		color: Theme.colors.subtext
		elide: Text.ElideRight
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}

	Loader {
		width: parent.width
		active: !!panel.looked
		visible: active

		sourceComponent: ClipboardLook {
			entry: panel.looked
			room: panel.listRoom
			focus: true
			Component.onCompleted: forceActiveFocus()
			onBack: panel.unlook()
			onPicked: paste => panel.pick(panel.looked, paste !== Settings.clipboard.paste)
			onRemoved: {
				Clipboard.remove(panel.looked);
				panel.unlook();
			}
		}
	}

	Item {
		width: parent.width
		height: list.count ? list.height : Theme.u(72)
		visible: !panel.looked

		Keys.onPressed: event => {
			panel.pinKey(event);
			if (event.accepted)
				return;
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

			function lookAt(index) {
				if (usable(index))
					panel.look(model[index]);
			}

			function togglePin(index) {
				if (!usable(index))
					return;
				if (model[index].pinned)
					Clipboard.unpin(model[index]);
				else
					Clipboard.pin(model[index]);
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
			onActivated: (index, entry) => panel.pick(entry, shiftHeld)
			Keys.onUpPressed: {
				if (currentIndex > 0)
					move(-1);
				else
					filter.take();
			}
			Keys.onDeletePressed: removeRow(currentIndex)
			Keys.onRightPressed: lookAt(currentIndex)
		}

		Text {
			anchors.fill: parent
			visible: list.count === 0
			text: Env.lacks("cliphist") || Env.lacks("wl-paste") ? `The history needs ${Env.lacks("cliphist") ? "cliphist" : "wl-clipboard"}, which isn't here`
				: Clipboard.entries.length ? "Nothing matches" : "Nothing copied yet"
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
