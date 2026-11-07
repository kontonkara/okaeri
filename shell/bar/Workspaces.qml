import QtQuick
import Quickshell
import qs
import qs.services

// niri's workspaces on `output`: a click goes to one, the wheel to the next, and
// one with a window wanting attention stands out. As Settings.workspaces has it,
// those with windows look apart from the empty ones, which can be left out, and a
// pill says its number or name.
Row {
	id: workspaces

	required property string output
	readonly property var own: Settings.workspaces
	readonly property var shown: own.empty ? Niri.on(output) : Niri.busyOn(output)
	readonly property bool labeled: own.labels !== "none"
	property int wheel: 0

	// By `delta` of the wheel, 120 to a notch, up being the one before.
	function turn(delta) {
		wheel += delta;
		const steps = Math.trunc(wheel / 120);
		if (steps === 0)
			return;
		wheel -= steps * 120;
		Niri.turn(shown, own.reverse ? -steps : steps);
	}

	spacing: Theme.u(6)

	Repeater {
		// By id, as each change makes them all anew: a pill that's made anew has
		// nothing to animate from.
		model: ScriptModel {
			values: workspaces.shown
			objectProp: "id"
		}

		Rectangle {
			id: pill

			required property var modelData
			readonly property string name: modelData.name || `${modelData.idx}`
			readonly property bool lit: modelData.is_active || modelData.is_urgent

			anchors.verticalCenter: parent.verticalCenter
			width: workspaces.labeled ? Math.max(Theme.u(modelData.is_active ? 28 : 18), Math.ceil(label.implicitWidth + Theme.u(12))) : Theme.u(modelData.is_active ? 28 : 12)
			height: Theme.u(workspaces.labeled ? 18 : 12)
			radius: Theme.round(height)
			// With those with windows marked, the empty ones fade, in case the
			// accent is pale too.
			color: modelData.is_active ? Theme.colors.accent
				: modelData.is_urgent ? Theme.colors.error
				: !workspaces.own.occupied ? Theme.colors.dim
				: Niri.holds(modelData) ? Qt.alpha(Theme.colors.accent, 0.6)
				: Qt.alpha(Theme.colors.text, 0.25)

			Behavior on width {
				enabled: Theme.animate

				NumberAnimation {
					duration: 180
					easing.type: Easing.OutCubic
				}
			}

			Text {
				id: label

				anchors.centerIn: parent
				visible: workspaces.labeled
				// A long name would take the bar.
				text: (workspaces.own.labels === "name" ? pill.name : `${pill.modelData.idx}`).slice(0, 12)
				textFormat: Text.PlainText
				color: pill.lit ? Theme.colors.background : Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.u(11)
				font.weight: Font.Bold
			}

			MouseArea {
				anchors.fill: parent
				anchors.leftMargin: -Theme.u(3)
				anchors.rightMargin: -Theme.u(3)
				anchors.topMargin: -(Theme.barHeight - parent.height) / 2 + Theme.u(2)
				anchors.bottomMargin: -(Theme.barHeight - parent.height) / 2 + Theme.u(2)
				cursorShape: Qt.PointingHandCursor
				onClicked: Niri.focus(parent.modelData.id)
				onWheel: event => workspaces.turn(event.angleDelta.y)
			}
		}
	}
}
