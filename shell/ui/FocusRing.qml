import QtQuick
import qs

// The ring around what Tab took the keys to, a little out from its edges:
// fill the thing with it, and give it the thing's corner radius.
Rectangle {
	property real cornerRadius: 0
	readonly property real gap: Theme.u(3)

	anchors.margins: -gap - border.width
	// Around a square corner it's square too.
	radius: cornerRadius > 0 ? cornerRadius - anchors.margins : 0
	color: "transparent"
	border.width: Math.max(1, Theme.u(2))
	border.color: Theme.colors.accent
}
