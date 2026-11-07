import QtQuick
import qs
import qs.ui

// For the bar: opens and closes the control center.
Button {
	height: Theme.u(28)
	flat: true
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	icon: "sliders"
	tip: "Control center"
	onClicked: Control.toggle()
}
