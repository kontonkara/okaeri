import QtQuick
import qs
import qs.services
import qs.ui

// Where the sound goes, with more than one place for it, a click moving it
// there, and the volume of each app playing, with a way to mute it.
Section {
	id: section

	name: "sound"
	icon: "volume"
	title: "Sound"
	summary: Audio.sink?.description ?? ""
	switches: false
	// A screen may have come since the last time.
	onUnfoldedChanged: {
		if (unfolded)
			Audio.checkScreens();
	}

	Heading {
		visible: Audio.outputs.length > 1
		text: "Output"
	}

	Rows {
		visible: Audio.outputs.length > 1
		values: Audio.outputs
		room: section.roomInside / 2
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

	Heading {
		text: "Apps"
	}

	Text {
		width: parent.width
		visible: Audio.nodes.length === 0
		leftPadding: Theme.u(10)
		bottomPadding: Theme.u(8)
		text: "Nothing plays"
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}

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

	component Heading: Text {
		width: parent.width
		leftPadding: Theme.u(10)
		topPadding: Theme.u(6)
		bottomPadding: Theme.u(4)
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}
}
