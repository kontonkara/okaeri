import QtQuick
import qs
import qs.services
import qs.ui

// The night light, from the bar, where there's a wlsunset for it: lit while
// it's on, a click turns it on or off, and the wheel makes it warmer or cooler.
BarButton {
	readonly property bool wanted: NightLight.available

	visible: wanted
	takesWheel: true
	icon: "sunset"
	tip: NightLight.on ? `Night light: ${NightLight.summary}` : "Night light"
	ink: NightLight.on ? Theme.colors.text : Theme.colors.dim
	onClicked: NightLight.set(!NightLight.on)
	onScrolled: steps => NightLight.step(-steps)
}
