import QtQuick
import qs
import qs.services
import qs.ui

// The volume and the microphone, with a way to mute them, the brightness when
// there's one, and that of external monitors when Ddc has them.
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
			visible: Audio.micReady
			value: Audio.micVolume
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
