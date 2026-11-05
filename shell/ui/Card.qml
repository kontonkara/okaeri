import QtQuick
import qs

// A surface for things that belong together, under a `title` if it has one.
// What's put in it goes one under another.
Rectangle {
	id: card

	property string title
	property real padding: Theme.u(14)
	default property alias content: body.data

	// Whole pixels: a window would cut a fraction off, and an edge would smear.
	implicitWidth: Math.ceil(body.implicitWidth + padding * 2)
	implicitHeight: Math.ceil(body.implicitHeight + padding * 2)
	radius: Theme.cardRadius
	color: Theme.colors.surface
	border.width: 1
	border.color: Theme.border

	Column {
		id: body

		x: card.padding
		y: card.padding
		width: card.width - card.padding * 2
		spacing: Theme.u(10)

		Text {
			visible: card.title !== ""
			text: card.title
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
			font.weight: Theme.fontWeight
		}
	}
}
