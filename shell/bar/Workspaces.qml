import QtQuick
import Quickshell
import qs
import qs.services

// niri's workspaces on `output`: a click goes to one, the wheel to the next, and
// one with a window wanting attention stands out.
Row {
	id: workspaces

	required property string output
	property int wheel: 0

	// By `delta` of the wheel, 120 to a notch, up being the one before.
	function turn(delta) {
		wheel += delta;
		const steps = Math.trunc(wheel / 120);
		if (steps === 0)
			return;
		wheel -= steps * 120;
		const all = Niri.on(output);
		const at = all.findIndex(w => w.is_active);
		const to = Math.max(0, Math.min(all.length - 1, at - steps));
		if (to !== at)
			Niri.focus(all[to].id);
	}

	spacing: Theme.u(6)

	Repeater {
		// By id, as each change makes them all anew: a pill that's made anew has
		// nothing to animate from.
		model: ScriptModel {
			values: Niri.on(workspaces.output)
			objectProp: "id"
		}

		Rectangle {
			required property var modelData

			anchors.verticalCenter: parent.verticalCenter
			width: Theme.u(modelData.is_active ? 28 : 12)
			height: Theme.u(12)
			radius: Theme.round(height)
			color: modelData.is_active ? Theme.colors.accent : modelData.is_urgent ? Theme.colors.error : Theme.colors.dim

			Behavior on width {
				enabled: Theme.animate

				NumberAnimation {
					duration: 180
					easing.type: Easing.OutCubic
				}
			}

			MouseArea {
				anchors.fill: parent
				anchors.leftMargin: -Theme.u(3)
				anchors.rightMargin: -Theme.u(3)
				anchors.topMargin: -Theme.u(11)
				anchors.bottomMargin: -Theme.u(11)
				cursorShape: Qt.PointingHandCursor
				onClicked: Niri.focus(parent.modelData.id)
				onWheel: event => workspaces.turn(event.angleDelta.y)
			}
		}
	}
}
