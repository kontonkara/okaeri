import QtQuick
import qs
import qs.ui

// For the bar: opens and closes the control center.
BarButton {
	icon: "sliders"
	tip: "Control center"
	onClicked: Control.toggle()
}
