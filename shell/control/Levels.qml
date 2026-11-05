import QtQuick
import qs
import qs.services
import qs.ui

// The volume, with a way to mute it, and the brightness when there's one.
Card {
	width: parent.width
	padding: Theme.u(6)

	Column {
		width: parent.width

		Level {
			enabled: Audio.ready
			value: Audio.volume
			onMoved: wanted => Audio.change(wanted - Audio.volume)

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
	}
}
