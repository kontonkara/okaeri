import QtQuick
import qs
import qs.services
import qs.ui

// Where the sound goes, with more than one place for it. A click moves it there.
Section {
	id: section

	property real room: 0

	name: "output"
	wanted: Audio.outputs.length > 1
	icon: "volume"
	title: "Output"
	summary: Audio.sink?.description ?? ""
	checked: true
	switches: false
	// A screen may have come since the last time.
	Component.onCompleted: Audio.checkScreens()

	Rows {
		values: Audio.outputs
		room: section.room
		onActivated: (index, node) => Audio.use(node)

		delegate: Entry {
			id: row

			// One that went away is null here for a moment, as the row goes.
			readonly property var node: modelData ?? ({})
			readonly property bool current: node === Audio.sink

			text: node.description ?? ""
			subtext: node.nickname ?? ""
			pickable: !current

			Icon {
				name: row.current ? "check" : "volume"
				color: row.current ? Theme.colors.text : Theme.colors.subtext
			}
		}
	}
}
