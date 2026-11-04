import QtQuick
import qs
import qs.services

// niri's workspaces on `output`: a click goes to one.
Row {
	id: workspaces

	required property string output

	spacing: Theme.u(6)

	Repeater {
		model: Niri.on(workspaces.output)

		Rectangle {
			required property var modelData

			anchors.verticalCenter: parent.verticalCenter
			width: Theme.u(modelData.is_active ? 28 : 12)
			height: Theme.u(12)
			radius: Theme.round(height)
			color: modelData.is_active ? Theme.colors.accent : Theme.colors.dim

			Behavior on width {
				enabled: Theme.animate

				NumberAnimation {
					duration: 180
					easing.type: Easing.OutCubic
				}
			}

			MouseArea {
				anchors.fill: parent
				anchors.margins: -Theme.u(3)
				cursorShape: Qt.PointingHandCursor
				onClicked: Niri.focus(parent.modelData.id)
			}
		}
	}
}
