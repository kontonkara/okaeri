import QtQuick
import qs
import qs.services
import qs.ui

// The title of the window in focus, while there's one, cut off if it's long, and
// then whole under the pointer. On a bar at a side it runs down it.
Item {
	id: title

	readonly property string text: Niri.focusedWindow?.title ?? ""
	readonly property bool wanted: text !== ""
	readonly property bool upright: Settings.barSide

	implicitWidth: upright ? line.height : line.width
	implicitHeight: upright ? line.width : line.height

	Text {
		id: line

		anchors.centerIn: parent
		width: Math.min(implicitWidth, Theme.u(300))
		rotation: title.upright ? 90 : 0
		text: title.text
		textFormat: Text.PlainText
		maximumLineCount: 1
		color: Theme.colors.subtext
		elide: Text.ElideRight
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
	}

	Tip {
		text: line.truncated ? title.text : ""
	}
}
