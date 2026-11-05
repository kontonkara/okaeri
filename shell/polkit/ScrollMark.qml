import QtQuick
import qs

// How far along `view` is, a Flickable or a List, when there's more in it than
// it can show. It goes in there, and draws at the edge.
Rectangle {
	required property Flickable view

	parent: view
	x: view.width - width
	y: view.visibleArea.yPosition * view.height
	width: Theme.u(3)
	height: view.visibleArea.heightRatio * view.height
	visible: view.contentHeight > view.height
	radius: Theme.round(width)
	color: Theme.colors.dim
}
