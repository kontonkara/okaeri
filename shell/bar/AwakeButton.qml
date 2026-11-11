import QtQuick
import qs
import qs.services
import qs.ui

// Keeping awake, from the bar: lit while it's on, a click turns it on or off,
// and the wheel on it gives it half an hour more or less.
Button {
	readonly property bool wanted: true

	height: Theme.u(28)
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	takesWheel: true
	icon: "coffee"
	tip: !Awake.on ? "Keep awake" : Awake.label ? `Kept awake for ${Awake.label}` : "Kept awake"
	ink: Awake.on ? Theme.colors.text : Theme.colors.dim
	onClicked: Awake.toggle()
	onScrolled: steps => Awake.step(steps)
}
