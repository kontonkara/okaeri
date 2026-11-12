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
// "workspaces" or "none". It's at the top of the screen, or at the bottom or a side
// with Settings.bar.position: at a side the lanes run down it and its parts stand
// upright. With Settings.bar.autoHide it's out of sight, and
// windows have the whole screen, until the pointer rests at that edge of the screen
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
	// Where it is, and whether that's a side, where it stands upright.
	readonly property string at: Settings.barAt
	readonly property bool upright: Settings.barSide
	// How far its tips are from the screen's edge, and on which side of it, for Tip.
	readonly property real tipsFrom: Theme.barHeight + Theme.u(6)
	readonly property string tipsAt: ({ top: "below", bottom: "above", left: "right", right: "left" })[at]
	// With no gap around it, it's against the screen's edges: square there.
	readonly property real corners: Theme.edge > 0 ? Theme.cardRadius : 0
	readonly property bool hides: Settings.bar.autoHide
	// What has it in sight then: the pointer at the top of the screen or on it,
	// and a panel on its screen.
	readonly property bool pointed: sensor.containsMouse || over.hovered
	readonly property bool called: Panels.open.some(panel => panel.screen === bar.screen)
	property bool down: true
	// How far it goes to be out of sight.
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
		top: at !== "bottom"
		bottom: at !== "top"
		left: at !== "right"
		right: at !== "left"
	}
	margins {
		top: at === "bottom" ? 0 : Theme.edge
		bottom: at === "top" ? 0 : Theme.edge
		left: at === "right" ? 0 : Theme.edge
		right: at === "left" ? 0 : Theme.edge
	}
	implicitWidth: Theme.barHeight
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

	// The edge of the screen the bar is at, for the pointer to bring it back: a line of
	// pixels, as a click there is this one's and no window's. With the bar in sight
	// it's the gap over the bar, where the theme has one, and without a gap it
	// makes way for the bar, whose top it would cover.
	PanelWindow {
		screen: bar.screen
		visible: bar.hides && (Theme.edge > 0 || !bar.visible)
		anchors {
			top: bar.at !== "bottom"
			bottom: bar.at !== "top"
			left: bar.at !== "right"
			right: bar.at !== "left"
		}
		implicitWidth: bar.visible ? Math.max(1, Theme.edge) : 1
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

		x: Math.round(body.x) + 1
		y: Math.round(body.y) + 1
		width: bar.width - 2
		height: bar.height - 2
		radius: bar.corners
	}

	// What a lane has, one beside another, or one under another on a bar at a side:
	// in a row with room for more than there ever are, or in a column.
	component Lane: Grid {
		id: lane

		required property var names
		// What the clock can take, if it's here.
		property real room: Infinity

		columns: bar.upright ? 1 : 1000
		horizontalItemAlignment: Grid.AlignHCenter
		verticalItemAlignment: Grid.AlignVCenter
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
			leftPadding: Settings.barSide ? 0 : Theme.u(6)
			rightPadding: Settings.barSide ? 0 : Theme.u(6)
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

	// All of it, which goes out of sight with a bar that hides.
	Item {
		id: body

		width: parent.width
		height: parent.height
		// How far out of its place it is, 0 in sight and `away` out of it: up, down
		// or to its side, as the edge it's at is.
		property real out: bar.down ? 0 : bar.away

		x: bar.at === "left" ? -out : bar.at === "right" ? out : 0
		y: bar.at === "top" ? -out : bar.at === "bottom" ? out : 0

		onOutChanged: {
			if (out === bar.away && !bar.down)
				bar.visible = false;
		}

		Behavior on out {
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
				else if (does === "brightness" || (does === "split" && (bar.upright ? event.y < height / 2 : event.x < width / 2)))
					Brightness.change(steps * 0.05);
				else if (does === "volume" || does === "split")
					Audio.change(steps * 0.05);
			}
		}

		// The lanes along the bar, from its left or its top, each in its middle the
		// other way.
		Lane {
			id: left

			x: bar.upright ? Math.round((parent.width - width) / 2) : Theme.u(14)
			y: bar.upright ? Theme.u(14) : (parent.height - height) / 2
			names: Settings.bar.left
		}

		// In the middle, or beside the last one on a narrow screen.
		Lane {
			id: center

			readonly property real from: (bar.upright ? left.y + left.height : left.x + left.width) + Theme.u(12)
			readonly property real to: (bar.upright ? right.y : right.x) - Theme.u(12)
			readonly property real length: bar.upright ? height : width
			readonly property real along: Math.round(Math.max(from, Math.min(((bar.upright ? parent.height : parent.width) - length) / 2, to - length)))

			x: bar.upright ? Math.round((parent.width - width) / 2) : along
			y: bar.upright ? along : (parent.height - height) / 2
			names: Settings.bar.center
			room: bar.upright ? Infinity : to - from
		}

		Lane {
			id: right

			x: bar.upright ? Math.round((parent.width - width) / 2) : parent.width - width - Theme.u(8)
			y: bar.upright ? parent.height - height - Theme.u(8) : (parent.height - height) / 2
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
