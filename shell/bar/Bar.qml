import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.clipboard
import qs.control
import qs.notifications
import qs.services

// The bar of a screen: what Settings.bar names on its left, in its middle and
// on its right, out of `parts`. The wheel on what doesn't use it does what
// Settings.bar.wheel says: "split" changes the brightness on its left half and the
// volume on its right, or it's "volume", "brightness", "workspaces" or "none".
PanelWindow {
	id: bar

	readonly property var parts: ({
		battery,
		bluetooth,
		cast,
		clipboard,
		clock,
		control,
		keyboard,
		media,
		network,
		notifications,
		privacy,
		system,
		title,
		tray,
		units,
		workspaces
	})
	// Under all of it, for Tip.
	readonly property real tipsFrom: Theme.barHeight + Theme.u(6)

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
	BackgroundEffect.blurRegion: Theme.barBlur ? glass : null

	// A pixel in from the edge: its corners come in steps, and stay under the fill's.
	Region {
		id: glass

		x: 1
		y: 1
		width: bar.width - 2
		height: bar.height - 2
		radius: Theme.cardRadius
	}

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
		id: bluetooth

		BluetoothButton {}
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
		id: media

		NowPlaying {}
	}

	Component {
		id: network

		NetworkButton {}
	}

	Component {
		id: privacy

		PrivacyIndicator {}
	}

	Component {
		id: system

		SystemLoad {}
	}

	Component {
		id: notifications

		NotificationsButton {}
	}

	Component {
		id: title

		WindowTitle {}
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
		color: Theme.barFill
	}

	// Over the fill, as on a panel: under the glass a border of its own would show
	// as a light line.
	Rectangle {
		anchors.fill: parent
		radius: Theme.cardRadius
		color: "transparent"
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
			const does = Settings.bar.wheel;
			if (does === "workspaces")
				Niri.turn(Settings.workspaces.empty ? Niri.on(bar.screen.name) : Niri.busyOn(bar.screen.name), Settings.workspaces.reverse ? -steps : steps);
			else if (does === "brightness" || (does === "split" && event.x < width / 2))
				Brightness.change(steps * 0.05);
			else if (does === "volume" || does === "split")
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
