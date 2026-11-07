import QtQuick
import qs
import qs.services
import qs.ui

// The title of the window in focus, while there's one, cut off if it's long, and
// then whole under the pointer.
Text {
	id: line

	readonly property string title: Niri.focusedWindow?.title ?? ""
	readonly property bool wanted: title !== ""

	width: Math.min(implicitWidth, Theme.u(300))
	text: title
	textFormat: Text.PlainText
	maximumLineCount: 1
	color: Theme.colors.subtext
	elide: Text.ElideRight
	font.family: Theme.font
	font.pixelSize: Theme.fontSize

	Tip {
		text: line.truncated ? line.title : ""
	}
}
