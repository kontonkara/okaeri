import QtQuick
import Quickshell.Services.UPower
import qs
import qs.services
import qs.ui

// The power profile, where there's more than one: which it is, and a click or
// the wheel goes on to the next.
BarButton {
	readonly property bool wanted: Power.choices.length > 1

	visible: wanted
	takesWheel: true
	icon: "bolt"
	text: Settings.profile.label === "name" && !stacked ? Power.profileName : ""
	tip: [`Power profile: ${Power.profileName}`, Power.profileWhy].filter(part => part !== "").join(" · ")
	ink: Power.profile === PowerProfile.Balanced ? Theme.colors.subtext : Power.profile === PowerProfile.Performance ? Theme.colors.text : Theme.colors.accent
	onClicked: Power.turn(1)
	onScrolled: steps => Power.turn(-steps)
}
