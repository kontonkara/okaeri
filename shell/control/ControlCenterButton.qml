import QtQuick
import qs
import qs.ui

// For the bar: opens and closes the control center, by itself.
BarButton {
	id: button

	icon: "sliders"
	tip: Tr.t("Control center")
	onClicked: Control.toggleFrom(button, "control", "")

	// For the pointer resting on it, with Settings.bar.hoverOpens.
	function flip() {
		Control.toggleFrom(button, "control", "");
	}
}
