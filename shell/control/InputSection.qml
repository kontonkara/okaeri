import QtQuick
import qs
import qs.services
import qs.ui

// Where the sound comes from, with more than one microphone, or with one and none
// chosen. A click takes it from there.
Section {
	id: section

	property real room: 0

	name: "input"
	wanted: Audio.inputs.length > 1 || (Audio.inputs.length > 0 && !Audio.source)
	icon: "mic"
	title: "Input"
	summary: Audio.source?.description ?? ""
	checked: true
	switches: false

	Rows {
		values: Audio.inputs
		room: section.room
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
