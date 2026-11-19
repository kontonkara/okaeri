import QtQuick
import qs
import qs.services
import qs.ui

// How many updates there are, by the package managers there are: there only while
// there's one. The pointer on it says how many of each, and a click runs
// Settings.updates.command, a terminal with the update say.
BarButton {
	readonly property bool wanted: Updates.count > 0

	icon: "download"
	text: String(Updates.count)
	tip: Updates.there.filter(source => Updates.found[source].length > 0).map(source => `${source}: ${Updates.found[source].length}`).join(" · ") + (Settings.updates.command ? "" : " · A click runs what the Bar page says")
	onClicked: Updates.run()

	Component.onCompleted: Updates.users += 1
	Component.onDestruction: Updates.users -= 1
}
