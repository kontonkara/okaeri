import QtQuick
import qs
import qs.services
import qs.ui

// The volume of each app playing, while any is, and a way to mute it, folded so
// that what plays doesn't make the panel grow by itself.
Section {
	name: "playback"
	wanted: Audio.nodes.length > 0
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

			Button {
				anchors.centerIn: parent
				height: Theme.u(28)
				flat: true
				icon: modelData.audio.muted ? "volumeOff" : "volume"
				iconSize: Theme.u(16)
				ink: modelData.audio.muted ? Theme.colors.subtext : Theme.colors.text
				onClicked: Audio.toggleStream(modelData)
			}
		}
	}
}
