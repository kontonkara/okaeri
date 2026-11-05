import QtQuick
import Quickshell
import qs
import qs.ui

// A List for what changes as it's looked at: `values`, in a ScriptModel, which
// moves rows instead of making them anew. The list stays where it's scrolled
// to and a row keeps what's typed in it. It's no taller than `room`, and shows
// eight rows and a half at most, the half saying there's more; `empty` says
// what it means when there's nothing in it.
List {
	id: rows

	property var values: []
	property real room: 0
	property string empty

	width: parent.width
	height: Math.max(rowHeight, Math.min(contentHeight, rowHeight * 8.5, room))
	// Rows hold state, so none goes away when it's scrolled out of sight.
	cacheBuffer: Theme.u(4000)
	model: ScriptModel {
		values: rows.values
	}

	// A current row is for the keys, and only while they're here: it would take
	// them from a field in a row, and Tab needs something to land on.
	onActiveFocusChanged: {
		if (!activeFocus)
			currentIndex = -1;
		else if (currentIndex < 0 && Window.activeFocusItem === rows)
			currentIndex = 0;
	}

	Text {
		parent: rows
		anchors.centerIn: parent
		visible: rows.count === 0
		text: rows.empty
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}
}
