import QtQuick
import qs

// The ring around what Tab took the keys to, a little out from its edges:
// fill the thing with it, and give it the thing's corner radius.
Rectangle {
	property real cornerRadius: 0
	readonly property real gap: Theme.u(3)

	anchors.margins: -gap - border.width
	radius: cornerRadius + gap + border.width
	color: "transparent"
	border.width: Math.max(1, Theme.u(2))
	border.color: Theme.colors.accent
}
