import QtQuick
import qs
import qs.services

// Keeping the machine awake: the switch for as long as it stays on, the wheel for
// half an hour at a time.
Section {
	name: "awake"
	icon: "coffee"
	title: "Keep awake"
	summary: !Awake.on ? "Off" : Awake.label || "It won't lock or dim"
	checked: Awake.on
	folds: false
	takesWheel: true
	onToggled: wanted => Awake.set(wanted, 0)
	onScrolled: steps => Awake.step(steps)
}
