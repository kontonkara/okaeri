import QtQuick
import qs
import qs.services
import qs.ui

// How loud the sound is across its pitches, as bars that rise and fall: there
// while cava is, and with Settings.visualizer.playing only while a player plays.
// Across a bar at a side too.
Item {
	id: part

	readonly property bool wanted: Visualizer.found && (!Settings.visualizer.playing || Media.playing)
	readonly property real tall: Theme.u(16)

	implicitWidth: Settings.barSide ? tall : bars.implicitWidth
	implicitHeight: Settings.barSide ? bars.implicitHeight : tall
	visible: wanted

	Component.onCompleted: Visualizer.users += 1
	Component.onDestruction: Visualizer.users -= 1

	Grid {
		id: bars

		anchors.centerIn: parent
		columns: Settings.barSide ? 1 : Settings.visualizer.bars
		spacing: Theme.u(2)
		horizontalItemAlignment: Grid.AlignHCenter
		verticalItemAlignment: Grid.AlignVCenter

		Repeater {
			model: Settings.visualizer.bars

			Rectangle {
				required property int index
				readonly property real level: Math.max(Theme.u(2), part.tall * (Visualizer.levels[index] ?? 0))

				width: Settings.barSide ? level : Theme.u(3)
				height: Settings.barSide ? Theme.u(3) : level
				radius: Theme.u(1.5)
				color: Theme.colors.text

				Behavior on height {
					enabled: Theme.animate
					NumberAnimation {
						duration: 60
					}
				}
			}
		}
	}
}
