import QtQuick
import qs
import qs.services
import qs.ui

// A plugin's part for the bar: what okaeri's own parts are made of is there to
// use, its look and its services. `wanted` false leaves it off the bar. What it
// says and whether it counts are its settings, on the Plugins page.
BarButton {
	property int clicks: 0
	readonly property bool wanted: true
	readonly property string greeting: Plugins.option("hello", "greeting") || "Hello"

	icon: "plugin"
	text: clicks > 0 && Plugins.option("hello", "count") ? `${greeting} ×${clicks}` : greeting
	tip: "A plugin's part"
	onClicked: clicks += 1
}
