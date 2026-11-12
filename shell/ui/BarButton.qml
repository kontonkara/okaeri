import QtQuick
import qs

// A button of the bar: as tall as its row there, with nothing around it until the
// pointer is on it. On a bar at a side it's as wide as that, and its text goes
// under its icon.
Button {
	stacked: Settings.barSide
	width: stacked ? Theme.u(28) : implicitWidth
	height: stacked ? implicitHeight : Theme.u(28)
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
}
