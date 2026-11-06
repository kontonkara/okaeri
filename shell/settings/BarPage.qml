import QtQuick
import Quickshell
import qs
import qs.ui

// The bar laid out: what's on its left, in its middle, on its right and what's
// off it. A part is dragged to where it goes, and the bar follows as it's let
// go. The control center stays on: the way here goes through it.
Item {
	id: page

	readonly property var names: ({
		battery: "Battery",
		cast: "Screen sharing",
		clipboard: "Clipboard",
		clock: "Clock",
		control: "Control center",
		keyboard: "Keyboard layout",
		notifications: "Notifications",
		tray: "Tray",
		units: "Failed units",
		workspaces: "Workspaces"
	})
	readonly property var lanes: [
		{ name: "left", text: "Left" },
		{ name: "center", text: "Middle" },
		{ name: "right", text: "Right" },
		{ name: "off", text: "Not on the bar" }
	]
	readonly property var settled: {
		const bar = Settings.bar;
		const on = bar.left.concat(bar.center, bar.right);
		return {
			left: bar.left,
			center: bar.center,
			right: bar.right,
			off: Object.keys(names).filter(name => !on.includes(name))
		};
	}
	// The part being dragged, and how things would be if it were let go now.
	property string held
	property var moved: null
	readonly property var shown: moved ?? settled

	function chipAt(x, y) {
		for (let index = 0; index < rows.count; index++) {
			const flow = rows.itemAt(index).flow;
			const at = flow.mapFromItem(page, x, y);
			const chip = flow.childAt(at.x, at.y);
			if (chip)
				return chip;
		}
		return null;
	}

	// The held part goes where the pointer is, among what's there. Outside the
	// lanes it stays where it last was.
	function place(x, y) {
		for (let index = 0; index < rows.count; index++) {
			const lane = rows.itemAt(index);
			if (!lane.contains(lane.mapFromItem(page, x, y)) || (lane.name === "off" && held === "control"))
				continue;
			const at = lane.flow.mapFromItem(page, x, y);
			const others = Array.from(lane.flow.children).filter(chip => chip.name && chip.name !== held);
			const before = others.filter(chip => chip.y + chip.height <= at.y || (chip.y <= at.y && chip.x + chip.width / 2 < at.x)).length;
			const next = {};
			lanes.forEach(other => next[other.name] = shown[other.name].filter(name => name !== held));
			next[lane.name].splice(before, 0, held);
			moved = next;
			return;
		}
	}

	function drop() {
		if (moved) {
			["left", "center", "right"].filter(lane => moved[lane].join() !== Settings.bar[lane].join()).forEach(lane => Settings.set("bar", lane, moved[lane]));
		}
		held = "";
		moved = null;
	}

	component Chip: Rectangle {
		property string text
		property color ink: Theme.colors.text

		width: Math.ceil(label.implicitWidth + Theme.u(24))
		height: Theme.u(30)
		radius: Theme.round(height)
		color: Qt.alpha(Theme.colors.text, 0.1)

		Text {
			id: label

			anchors.centerIn: parent
			text: parent.text
			textFormat: Text.PlainText
			color: parent.ink
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}
	}

	Column {
		width: parent.width
		spacing: Math.round(Theme.u(10))

		Repeater {
			id: rows

			model: page.lanes

			Card {
				id: lane

				required property var modelData
				readonly property string name: modelData.name
				readonly property Flow flow: chips

				width: parent.width
				padding: Theme.u(10)
				title: modelData.text

				Flow {
					id: chips

					width: parent.width
					// Two lines of parts: what's below shouldn't move as one comes in.
					height: Math.max(implicitHeight, Theme.u(66))
					spacing: Theme.u(6)

					move: Transition {
						enabled: Theme.animate

						NumberAnimation {
							properties: "x,y"
							duration: 120
							easing.type: Easing.OutCubic
						}
					}

					Repeater {
						model: ScriptModel {
							values: page.shown[lane.name]
						}

						Chip {
							required property string modelData
							readonly property string name: modelData

							text: page.names[name] ?? name
							opacity: name === page.held ? 0.3 : 1
						}
					}
				}
			}
		}

		Text {
			width: parent.width
			text: "Screen sharing, Failed units and Keyboard layout show only when they have something to say."
			wrapMode: Text.WordWrap
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	MouseArea {
		id: pointer

		// What it was pressed on, where, and how far from the corner of that.
		property string pressed
		property point start
		property point grip

		anchors.fill: parent
		hoverEnabled: true
		preventStealing: true
		cursorShape: page.held ? Qt.ClosedHandCursor : page.chipAt(mouseX, mouseY) ? Qt.OpenHandCursor : Qt.ArrowCursor

		onPressed: event => {
			const chip = page.chipAt(event.x, event.y);
			event.accepted = !!chip;
			if (chip) {
				pressed = chip.name;
				start = Qt.point(event.x, event.y);
				grip = chip.mapFromItem(page, event.x, event.y);
				ghost.width = chip.width;
			}
		}
		onPositionChanged: event => {
			if (!pressed)
				return;
			if (!page.held && Math.hypot(event.x - start.x, event.y - start.y) < Theme.u(6))
				return;
			page.held = pressed;
			page.place(event.x, event.y);
		}
		onReleased: {
			pressed = "";
			page.drop();
		}
		onCanceled: {
			pressed = "";
			page.held = "";
			page.moved = null;
		}
	}

	Chip {
		id: ghost

		x: pointer.mouseX - pointer.grip.x
		y: pointer.mouseY - pointer.grip.y
		visible: page.held !== ""
		text: page.names[page.held] ?? page.held
		color: Theme.colors.accent
		ink: Theme.colors.background
	}
}
