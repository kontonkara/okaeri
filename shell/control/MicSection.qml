import QtQuick
import qs
import qs.services
import qs.ui

// Where the sound comes from: the microphones there are, a click taking it
// from there.
Section {
	id: section

	name: "mic"
	icon: "mic"
	title: "Microphone"
	summary: Audio.source?.description ?? "None chosen"
	switches: false

	Rows {
		values: Audio.inputs
		room: section.roomInside
		empty: "No microphones"
		onActivated: (index, node) => Audio.useInput(node)

		delegate: Entry {
			id: row

			// One that went away is null here for a moment, as the row goes.
			readonly property var node: modelData ?? ({})
			readonly property bool current: node === Audio.source

			text: node.description ?? ""
			subtext: node.nickname ?? ""
			pickable: !current

			Icon {
				name: row.current ? "check" : "mic"
				color: row.current ? Theme.colors.text : Theme.colors.subtext
			}
		}
	}
}
