import QtQuick
import qs
import qs.services

// Warmer screens: the switch, and the wheel for how warm. How and when are on
// the Display page.
Section {
	name: "night"
	icon: "sunset"
	title: "Night light"
	summary: !NightLight.available ? "It needs wlsunset" : NightLight.on ? NightLight.summary : "Off"
	checked: NightLight.on && NightLight.available
	canSwitch: NightLight.available
	folds: false
	takesWheel: true
	onToggled: wanted => NightLight.set(wanted)
	onScrolled: steps => NightLight.step(-steps)
}
