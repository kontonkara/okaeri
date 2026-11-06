import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.clipboard
import qs.control
import qs.notifications
import qs.services

// The bar of a screen: what Settings.bar names on its left, in its middle and
// on its right, out of `parts`. The wheel on what doesn't use it changes the
// brightness on its left half and the volume on its right.
PanelWindow {
	id: bar

	readonly property var parts: ({
		battery,
		cast,
		clipboard,
		clock,
		control,
		keyboard,
		notifications,
		tray,
		units,
		workspaces
	})

	anchors {
		top: true
		left: true
		right: true
	}
	margins {
		top: Theme.edge
		left: Theme.edge
		right: Theme.edge
	}
	implicitHeight: Theme.barHeight
	color: "transparent"
	WlrLayershell.namespace: "okaeri-bar"

	component Lane: Row {
		id: lane

		required property var names
		// What the clock can take, if it's here.
		property real room: Infinity

		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.u(4)

		Repeater {
			model: lane.names

			Loader {
				required property string modelData
				readonly property real room: lane.room

				anchors.verticalCenter: parent.verticalCenter
				visible: item?.wanted ?? true
				sourceComponent: bar.parts[modelData] ?? null

				Component.onCompleted: {
					if (!sourceComponent)
						console.info(`okaeri: no "${modelData}" for the bar, it's one of ${Object.keys(bar.parts).join(", ")}`);
				}
			}
		}
	}

	Component {
		id: battery

		Battery {
			leftPadding: Theme.u(6)
			rightPadding: Theme.u(6)
		}
	}

	Component {
		id: cast

		Cast {}
	}

	Component {
		id: clipboard

		ClipboardButton {}
	}

	Component {
		id: keyboard

		KeyboardLayout {}
	}

	Component {
		id: clock

		Clock {
			room: parent ? parent.room : Infinity
		}
	}

	Component {
		id: control

		ControlCenterButton {}
	}

	Component {
		id: notifications

		NotificationsButton {}
	}

	Component {
		id: tray

		Tray {}
	}

	Component {
		id: units

		FailedUnits {}
	}

	Component {
		id: workspaces

		Workspaces {
			output: bar.screen ? bar.screen.name : ""
		}
	}

	Rectangle {
		id: background

		anchors.fill: parent
		radius: Theme.cardRadius
		color: Theme.colors.background
		border.width: 1
		border.color: Theme.border
	}

	MouseArea {
		property int wheel: 0

		anchors.fill: parent
		acceptedButtons: Qt.NoButton
		onWheel: event => {
			// A touchpad comes in small parts of a notch.
			wheel += event.angleDelta.y;
			const steps = Math.trunc(wheel / 120);
			if (steps === 0)
				return;
			wheel -= steps * 120;
			if (event.x < width / 2)
				Brightness.change(steps * 0.05);
			else
				Audio.change(steps * 0.05);
		}
	}

	Lane {
		id: left

		anchors.left: parent.left
		anchors.leftMargin: Theme.u(14)
		names: Settings.bar.left
	}

	// In the middle, or beside the right side on a narrow screen.
	Lane {
		id: center

		readonly property real from: left.x + left.width + Theme.u(12)
		readonly property real to: right.x - Theme.u(12)

		x: Math.round(Math.max(from, Math.min((parent.width - width) / 2, to - width)))
		names: Settings.bar.center
		room: to - from
	}

	Lane {
		id: right

		anchors.right: parent.right
		anchors.rightMargin: Theme.u(8)
		names: Settings.bar.right
	}

	// For tests/measure.sh: when the first frame went out.
	Connections {
		id: firstFrame

		target: background.Window.window

		function onFrameSwapped() {
			console.info("okaeri: first frame", Date.now());
			firstFrame.enabled = false;
		}
	}
}
