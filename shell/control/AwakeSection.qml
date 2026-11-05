import QtQuick
import qs.services

// Keeping the machine awake.
Section {
	name: "awake"
	icon: "coffee"
	title: "Keep awake"
	summary: Awake.on ? "It won't lock or dim" : "Off"
	checked: Awake.on
	folds: false
	onToggled: wanted => Awake.on = wanted
}
