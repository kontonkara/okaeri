import QtQuick
import qs
import qs.services
import qs.ui

// Where the sound comes from: the microphones there are, a click taking it
// from there, how loud the one in use hears it now, and the apps listening,
// each with its volume and a way to mute it for that app alone.
Section {
	id: section

	name: "mic"
	icon: "mic"
	title: "Microphone"
	summary: Audio.source?.description ?? "None chosen"
	switches: false

	Binding {
		target: Audio
		property: "hearing"
		value: section.unfolded
	}

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

	// How loud the one in use hears it now, while the page is open: from -60 dB
	// up, as a meter reads, so that a voice fills much of it.
	Item {
		width: parent.width
		height: Theme.u(20)
		visible: Audio.micReady

		Rectangle {
			id: meter

			readonly property real loud: Audio.micMuted ? 0 : Math.max(0, Math.min(1, (20 * Math.log10(Math.max(Audio.micPeak, 1e-6)) + 60) / 60))

			objectName: "micLevel"
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.margins: Theme.u(10)
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(6)
			radius: Theme.round(height)
			color: Qt.alpha(Theme.colors.text, 0.16)

			Rectangle {
				width: parent.width * meter.loud
				height: parent.height
				radius: parent.radius
				color: Theme.colors.accent

				Behavior on width {
					enabled: Theme.animate

					NumberAnimation {
						duration: 80
					}
				}
			}
		}
	}

	Text {
		width: parent.width
		leftPadding: Theme.u(10)
		topPadding: Theme.u(6)
		bottomPadding: Theme.u(4)
		text: "Apps"
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}

	Text {
		width: parent.width
		visible: Audio.listeners.length === 0
		leftPadding: Theme.u(10)
		bottomPadding: Theme.u(8)
		text: "Nothing listens"
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}

	Repeater {
		model: Audio.listeners

		Level {
			required property var modelData

			label: Audio.streamName(modelData)
			value: modelData.audio.volume
			onMoved: wanted => Audio.changeStream(modelData, wanted)

			Button {
				anchors.centerIn: parent
				height: Theme.u(28)
				flat: true
				icon: modelData.audio.muted ? "micOff" : "mic"
				iconSize: Theme.u(16)
				ink: modelData.audio.muted ? Theme.colors.subtext : Theme.colors.text
				onClicked: Audio.toggleStream(modelData)
			}
		}
	}
}
