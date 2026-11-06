import QtQuick
import qs
import qs.services
import qs.ui

// The volume of each app playing, while any is, folded so that what plays doesn't
// make the panel grow by itself.
Section {
	name: "playback"
	visible: Audio.nodes.length > 0
	icon: "music"
	title: "Playback"
	summary: [...new Set(Audio.nodes.map(node => Audio.streamName(node)))].join(", ")
	checked: true
	switches: false

	Repeater {
		model: Audio.nodes

		Level {
			required property var modelData

			label: Audio.streamName(modelData)
			value: modelData.audio.volume
			onMoved: wanted => Audio.changeStream(modelData, wanted)

			Icon {
				anchors.centerIn: parent
				name: "volume"
				size: Theme.u(16)
				color: Theme.colors.subtext
			}
		}
	}
}
