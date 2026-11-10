import QtQuick
import qs
import qs.services
import qs.ui

// The volume and the microphone, with a way to mute them and an arrow to their
// pages, the brightness when there's one, and that of external monitors when Ddc
// has them.
Card {
	width: parent.width
	padding: Theme.u(6)

	Column {
		width: parent.width

		Level {
			enabled: Audio.ready
			// Full at the limit.
			value: Audio.volume / Audio.limit
			full: Audio.limit
			opens: "sound"
			onMoved: wanted => Audio.change(wanted * Audio.limit - Audio.volume)

			Button {
				anchors.centerIn: parent
				height: Theme.u(28)
				flat: true
				icon: Audio.muted ? "volumeOff" : "volume"
				ink: Audio.muted ? Theme.colors.subtext : Theme.colors.text
				onClicked: Audio.toggleMute()
			}
		}

		Level {
			visible: Brightness.available
			value: Brightness.level
			onMoved: wanted => Brightness.change(wanted - Brightness.level)

			Icon {
				anchors.centerIn: parent
				name: "sun"
			}
		}

		Repeater {
			model: Ddc.displays.filter(display => display.level >= 0)

			Level {
				required property var modelData

				label: modelData.name
				value: modelData.level / modelData.max
				onMoved: wanted => Ddc.change(modelData, wanted)

				Icon {
					anchors.centerIn: parent
					name: "sun"
				}
			}
		}

		Level {
			// With a microphone there, but none chosen, it's there for its arrow.
			visible: Audio.micReady || Audio.inputs.length > 0
			value: Audio.micVolume
			opens: "mic"
			onMoved: wanted => Audio.changeMic(wanted - Audio.micVolume)

			Button {
				anchors.centerIn: parent
				height: Theme.u(28)
				flat: true
				icon: Audio.micMuted ? "micOff" : "mic"
				ink: Audio.micMuted ? Theme.colors.subtext : Theme.colors.text
				onClicked: Audio.toggleMicMute()
			}
		}
	}
}
