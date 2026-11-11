import QtQuick
import qs
import qs.services
import qs.ui

// The night light, from the bar, where there's a wlsunset for it: lit while
// it's on, a click turns it on or off, and the wheel makes it warmer or cooler.
Button {
	readonly property bool wanted: NightLight.available

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	takesWheel: true
	icon: "sunset"
	tip: NightLight.on ? `Night light: ${NightLight.summary}` : "Night light"
	ink: NightLight.on ? Theme.colors.text : Theme.colors.dim
	onClicked: NightLight.set(!NightLight.on)
	onScrolled: steps => NightLight.step(-steps)
}
