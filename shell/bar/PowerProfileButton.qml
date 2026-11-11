import QtQuick
import Quickshell.Services.UPower
import qs
import qs.services
import qs.ui

// The power profile, where there's more than one: which it is, and a click or
// the wheel goes on to the next.
Button {
	readonly property bool wanted: Power.choices.length > 1

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	takesWheel: true
	icon: "bolt"
	text: Settings.profile.label === "name" ? Power.profileName : ""
	tip: `Power profile: ${Power.profileName}`
	ink: Power.profile === PowerProfile.Balanced ? Theme.colors.subtext : Power.profile === PowerProfile.Performance ? Theme.colors.text : Theme.colors.accent
	onClicked: Power.turn(1)
	onScrolled: steps => Power.turn(-steps)
}
