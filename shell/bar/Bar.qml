import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.clipboard
import qs.control
import qs.notifications
import qs.services
import qs.ui

// The bar of a screen: what Settings.bar names on its left, in its middle and
// on its right, out of `parts` and the user's own, Settings.bar.scripts. A click
// or the wheel on a part runs what Settings.bar.actions has for it, { left,
// right, middle, up, down }, in place of what the part does. The wheel on what
// doesn't use it does what Settings.bar.wheel says: "split" changes the brightness
// on its left half and the volume on its right, or it's "volume", "brightness",
// "workspaces" or "none". With Settings.bar.autoHide it's out of sight, and
// windows have the whole screen, until the pointer rests at the top of the screen
// or a panel opens there.
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
		recording,
		system,
		title,
		tray,
		units,
		workspaces,
		locks,
		profile,
		awake,
		night
	})
	// Under all of it, for Tip.
	readonly property real tipsFrom: Theme.barHeight + Theme.u(6)
	// With no gap around it, it's against the screen's edges: square there.
	readonly property real corners: Theme.edge > 0 ? Theme.cardRadius : 0
	readonly property bool hides: Settings.bar.autoHide
	// What has it in sight then: the pointer at the top of the screen or on it,
	// and a panel on its screen.
	readonly property bool pointed: sensor.containsMouse || over.hovered
	readonly property bool called: Panels.open.some(panel => panel.screen === bar.screen)
	property bool down: true
	// How far up it goes to be out of sight.
	readonly property real away: Theme.edge + Theme.barHeight
	// Whether a frame of it has been on the screen.
	property bool seen: false

	// A panel has it at once. The pointer has to stay a moment, as it's often at
	// the top for a window's sake, and can leave for one. One that hasn't been seen
	// yet has nothing to leave slowly: the settings that say it hides come a
	// moment after it's made.
	function settle() {
		coming.stop();
		going.stop();
		if (!hides || called)
			down = true;
		else if (pointed && !down)
			coming.start();
		else if (!pointed && down) {
			if (seen) {
				going.start();
			} else {
				down = false;
				visible = false;
			}
		}
	}

	// A command of the user's, for a click or the wheel on a part: started by niri, as
	// an app is.
	function run(command) {
		Env.act(`run ${command}`, () => Niri.spawn(["sh", "-c", command]));
	}

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
	// Windows keep out from under it, unless Settings.bar.reserve says otherwise,
	// or it hides.
	exclusionMode: Settings.bar.reserve && !hides ? ExclusionMode.Auto : ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "okaeri-bar"
	BackgroundEffect.blurRegion: Theme.barBlur ? glass : null

	onHidesChanged: settle()
	onPointedChanged: settle()
	// Not while it's being worked out: a window that comes into sight says its screen
	// anew, which is part of what this comes from.
	onCalledChanged: Qt.callLater(settle)
	onDownChanged: {
		if (down)
			visible = true;
	}
	Component.onCompleted: settle()

	Timer {
		id: coming

		interval: 150
		onTriggered: bar.down = true
	}

	Timer {
		id: going

		interval: 400
		onTriggered: bar.down = false
	}

	// The top of the screen, for the pointer to bring the bar back: a line of
	// pixels, as a click there is this one's and no window's. With the bar in sight
	// it's the gap over the bar, where the theme has one, and without a gap it
	// makes way for the bar, whose top it would cover.
	PanelWindow {
		screen: bar.screen
		visible: bar.hides && (Theme.edge > 0 || !bar.visible)
		anchors {
			top: true
			left: true
			right: true
		}
		implicitHeight: bar.visible ? Math.max(1, Theme.edge) : 1
		exclusionMode: ExclusionMode.Ignore
		color: "transparent"
		WlrLayershell.namespace: "okaeri-edge"

		MouseArea {
			id: sensor

			anchors.fill: parent
			acceptedButtons: Qt.NoButton
			hoverEnabled: true
		}
	}

	// A pixel in from the edge: its corners come in steps, and stay under the fill's.
	Region {
		id: glass

		x: 1
		y: Math.round(body.y) + 1
		width: bar.width - 2
		height: bar.height - 2
		radius: bar.corners
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
				id: place

				required property string modelData
				readonly property real room: lane.room
				// What its clicks and the wheel on it run, by the button or the way.
				// The tray's icons are apps, with clicks of their own.
				readonly property var runs: modelData === "tray" ? ({}) : Settings.bar.actions[modelData] ?? ({})

				anchors.verticalCenter: parent.verticalCenter
				visible: item?.wanted ?? true
				sourceComponent: bar.parts[modelData] ?? (Settings.bar.scripts.some(own => own.name === modelData) ? script : null)

				Component.onCompleted: {
					if (!sourceComponent)
						console.info(`okaeri: no "${modelData}" for the bar, it's one of ${Object.keys(bar.parts).join(", ")}, or of the scripts`);
				}

				// Over the part, for the buttons that have a command, and the wheel
				// if either way has one: the rest and where the pointer is go
				// through to it. Only with a command, as the pointer has this one's
				// shape and not the part's.
				MouseArea {
					readonly property bool wheeled: !!place.runs.up || !!place.runs.down
					property int wheel: 0

					anchors.fill: parent
					z: 1
					visible: wheeled || acceptedButtons !== Qt.NoButton
					cursorShape: Qt.PointingHandCursor
					acceptedButtons: (place.runs.left ? Qt.LeftButton : Qt.NoButton) | (place.runs.right ? Qt.RightButton : Qt.NoButton) | (place.runs.middle ? Qt.MiddleButton : Qt.NoButton)
					onClicked: event => bar.run(place.runs[event.button === Qt.RightButton ? "right" : event.button === Qt.MiddleButton ? "middle" : "left"])
					onWheel: event => {
						if (!wheeled) {
							event.accepted = false;
							return;
						}
						// A touchpad comes in small parts of a notch.
						wheel += event.angleDelta.y;
						const steps = Math.trunc(wheel / 120);
						wheel -= steps * 120;
						const command = place.runs[steps > 0 ? "up" : "down"];
						for (let step = 0; command && step < Math.abs(steps); step++)
							bar.run(command);
					}
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
		id: recording

		Recording {}
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

	Component {
		id: locks

		LockKeys {}
	}

	Component {
		id: profile

		PowerProfileButton {}
	}

	Component {
		id: awake

		AwakeButton {}
	}

	Component {
		id: night

		NightButton {}
	}

	Component {
		id: script

		Script {
			name: parent ? parent.modelData : ""
		}
	}

	// All of it, which goes up out of sight with a bar that hides.
	Item {
		id: body

		width: parent.width
		height: parent.height
		y: bar.down ? 0 : -bar.away

		onYChanged: {
			if (y === -bar.away && !bar.down)
				bar.visible = false;
		}

		Behavior on y {
			enabled: Theme.animate

			NumberAnimation {
				duration: 180
				easing.type: Easing.OutCubic
			}
		}

		HoverHandler {
			id: over
		}

		Rectangle {
			id: background

			anchors.fill: parent
			radius: bar.corners
			color: Theme.barFill
		}

		// Over the fill, as on a panel: under the glass a border of its own would show
		// as a light line.
		Rectangle {
			anchors.fill: parent
			radius: bar.corners
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
	}

	// When the first frame went out, which tests/measure.sh times.
	Connections {
		id: firstFrame

		target: background.Window.window

		function onFrameSwapped() {
			console.info("okaeri: first frame", Date.now());
			bar.seen = true;
			firstFrame.enabled = false;
		}
	}
}
