import QtQuick
import Quickshell.Io
import qs

// The time in other places, Settings.clock.zones by their zones' names, as
// Europe/Berlin: asked of `date` as this shows and twice a minute after, with
// the day where that's another one than here.
Column {
	id: zones

	readonly property var names: Settings.clock.zones
	// What `date` said of each: "14:05|Wed".
	property var times: []
	readonly property string today: Qt.formatDateTime(new Date(), "ddd")

	visible: names.length > 0
	spacing: Theme.u(2)

	Process {
		id: asking

		command: ["sh", "-c", 'for zone in "$@"; do TZ="$zone" LC_ALL=C date "+$0"; done', Settings.clock.hours12 ? "%I:%M %p|%a" : "%H:%M|%a"].concat(zones.names)
		stdout: StdioCollector {
			onStreamFinished: zones.times = text.trim().split("\n")
		}
	}

	Timer {
		interval: 30000
		running: zones.visible
		repeat: true
		triggeredOnStart: true
		onTriggered: asking.running = true
	}

	Repeater {
		model: zones.names

		Item {
			required property string modelData
			required property int index
			readonly property var said: (zones.times[index] ?? "").split("|")

			width: zones.width
			height: Theme.u(24)

			// A zone's name is its place, after the last slash.
			Text {
				anchors.left: parent.left
				anchors.leftMargin: Theme.u(8)
				anchors.right: time.left
				anchors.rightMargin: Theme.u(8)
				anchors.verticalCenter: parent.verticalCenter
				text: parent.modelData.split("/").pop().replace(/_/g, " ")
				textFormat: Text.PlainText
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}

			Text {
				id: time

				anchors.right: parent.right
				anchors.rightMargin: Theme.u(8)
				anchors.verticalCenter: parent.verticalCenter
				text: [parent.said[1] && parent.said[1] !== zones.today ? parent.said[1] : "", parent.said[0] ?? ""].filter(part => part !== "").join("  ")
				color: Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
				font.features: {
					"tnum": 1
				}
			}
		}
	}
}
