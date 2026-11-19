import QtQuick
import qs
import qs.ui

// A plugin's part for the bar: what okaeri's own parts are made of is there to
// use, its look and its services. `wanted` false leaves it off the bar.
BarButton {
	property int clicks: 0
	readonly property bool wanted: true

	icon: "plugin"
	text: clicks > 0 ? `Hello ×${clicks}` : "Hello"
	tip: "A plugin's part"
	onClicked: clicks += 1
}
