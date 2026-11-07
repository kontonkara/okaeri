import QtQuick
import Quickshell
import qs
import qs.ui

// The bar laid out: what's on its left, in its middle, on its right and what's
// off it. A part is dragged to where it goes, and the bar follows as it's let
// go; a click on one shows what it has to set. The control center stays on, and
// a bar on one screen: the way here goes through it. Under them what's for all of
// the bar, and the screens it's on.
Flickable {
	id: page

	readonly property var names: ({
		battery: "Battery",
		cast: "Screen sharing",
		clipboard: "Clipboard",
		clock: "Clock",
		control: "Control center",
		keyboard: "Keyboard layout",
		media: "Media",
		notifications: "Notifications",
		title: "Window title",
		tray: "Tray",
		units: "Failed units",
		workspaces: "Workspaces"
	})
	// Those whose settings are on a page of their own, by its name.
	readonly property var elsewhere: ({
		clipboard: "Clipboard",
		control: "Control center",
		notifications: "Notifications",
		tray: "Tray"
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
	// The part whose settings show.
	property string chosen
	// The screens there are, and those left without a bar that aren't there now.
	readonly property var screens: {
		const there = Quickshell.screens.map(screen => ({
			name: screen.name,
			about: [screen.model, `${screen.width}×${screen.height}`].filter(part => !!part).join(" · "),
			there: true
		}));
		const gone = Settings.bar.hideOn.filter(name => !there.some(screen => screen.name === name)).map(name => ({ name, about: "Not connected", there: false }));
		return there.concat(gone);
	}
	readonly property int bars: Quickshell.screens.filter(screen => Settings.barOn(screen)).length

	// For a page of the settings window, by its name.
	signal opens(string name)

	function chipAt(x, y) {
		for (let index = 0; index < rows.count; index++) {
			const flow = rows.itemAt(index).flow;
			const at = flow.mapFromItem(board, x, y);
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
			if (!lane.contains(lane.mapFromItem(board, x, y)) || (lane.name === "off" && held === "control"))
				continue;
			const at = lane.flow.mapFromItem(board, x, y);
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

	function showOn(name, wanted) {
		const others = Settings.bar.hideOn.filter(other => other !== name);
		Settings.set("bar", "hideOn", wanted ? others : others.concat([name]));
	}

	contentHeight: stack.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds
	// The part's settings come up under the lanes, where they may not show yet.
	onChosenChanged: {
		if (chosen)
			revealing.restart();
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

	component Note: Text {
		width: parent.width
		wrapMode: Text.WordWrap
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}

	Glide {
		id: glide

		view: page
	}

	// Once what's in the card has its place.
	Timer {
		id: revealing

		interval: 30
		onTriggered: glide.reveal(part.y, part.y + part.height)
	}

	Column {
		id: stack

		width: parent.width
		spacing: Math.round(Theme.u(10))

		Item {
			id: board

			width: parent.width
			height: layout.height

			Column {
				id: layout

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
									color: name === page.chosen ? Qt.alpha(Theme.colors.accent, 0.3) : Qt.alpha(Theme.colors.text, 0.1)
									opacity: name === page.held ? 0.3 : 1
								}
							}
						}
					}
				}

				Note {
					text: "A click on a part shows its settings. Media, Screen sharing, Failed units and Keyboard layout show only when they have something to say."
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
						grip = chip.mapFromItem(board, event.x, event.y);
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
					// Let go where it was pressed: a click.
					if (pressed && !page.held)
						page.chosen = page.chosen === pressed ? "" : pressed;
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

		Card {
			id: part

			width: parent.width
			visible: page.chosen !== ""
			title: page.names[page.chosen] ?? page.chosen

			Loader {
				width: parent.width
				sourceComponent: ({
						clock: clockSettings,
						workspaces: workspaceSettings,
						battery: batterySettings
					})[page.chosen] ?? (page.elsewhere[page.chosen] ? elsewhereSettings : nothingSettings)
			}
		}

		Card {
			width: parent.width
			title: "All of the bar"

			Pick {
				text: "The wheel on it"
				subtext: Settings.bar.wheel === "split" ? "Brightness on the left half, volume on the right" : "Where no part takes it"
				options: [
					{ value: "split", text: "Split" },
					{ value: "volume", text: "Volume" },
					{ value: "brightness", text: "Brightness" },
					{ value: "workspaces", text: "Workspaces" },
					{ value: "none", text: "Nothing" }
				]
				value: Settings.bar.wheel
				onChosen: value => Settings.set("bar", "wheel", value)
			}

			Setting {
				text: "Tips"
				subtext: "What a part is or says, under the pointer"
				checked: Settings.bar.tips
				onToggled: wanted => Settings.set("bar", "tips", wanted)
			}
		}

		Card {
			width: parent.width
			title: "Screens"

			Repeater {
				model: page.screens

				Setting {
					required property var modelData
					readonly property bool on: !Settings.bar.hideOn.includes(modelData.name)

					text: modelData.name
					subtext: modelData.about
					checked: on
					// The last bar stays.
					enabled: !(on && modelData.there && page.bars <= 1)
					onToggled: wanted => page.showOn(modelData.name, wanted)
				}
			}
		}
	}

	Component {
		id: clockSettings

		Column {
			spacing: Theme.u(10)

			Pick {
				text: "The date"
				subtext: "Beside the time"
				options: [
					{ value: "before", text: "Before" },
					{ value: "after", text: "After" },
					{ value: "none", text: "None" }
				]
				value: Settings.clock.date
				onChosen: value => Settings.set("clock", "date", value)
			}

			Item {
				width: parent.width
				height: Theme.u(40)
				visible: Settings.clock.date !== "none"

				Column {
					anchors.left: parent.left
					anchors.right: format.left
					anchors.rightMargin: Theme.u(12)
					anchors.verticalCenter: parent.verticalCenter

					Text {
						width: parent.width
						text: "How it's written"
						color: Theme.colors.text
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Text {
						width: parent.width
						text: "In Qt's letters, Enter to keep: ddd d MMM is Sat 7 Nov"
						color: Theme.colors.subtext
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize - Theme.u(2)
					}
				}

				TextField {
					id: format

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					implicitWidth: Theme.u(170)
					implicitHeight: Theme.u(32)
					placeholder: "ddd d MMM"
					text: Settings.clock.dateFormat
					onAccepted: Settings.set("clock", "dateFormat", text.trim())
				}
			}

			Setting {
				text: "12-hour time"
				subtext: "With AM and PM"
				checked: Settings.clock.hours12
				onToggled: wanted => Settings.set("clock", "hours12", wanted)
			}

			Setting {
				text: "Seconds"
				checked: Settings.clock.seconds
				onToggled: wanted => Settings.set("clock", "seconds", wanted)
			}
		}
	}

	Component {
		id: workspaceSettings

		Column {
			spacing: Theme.u(10)

			Pick {
				text: "On each"
				subtext: "A name is niri's, where its config gives one"
				options: [
					{ value: "none", text: "Nothing" },
					{ value: "number", text: "Its number" },
					{ value: "name", text: "Its name" }
				]
				value: Settings.workspaces.labels
				onChosen: value => Settings.set("workspaces", "labels", value)
			}

			Setting {
				text: "Those with windows stand out"
				checked: Settings.workspaces.occupied
				onToggled: wanted => Settings.set("workspaces", "occupied", wanted)
			}

			Setting {
				text: "Empty ones too"
				subtext: "Off, only those with windows and the one you're on"
				checked: Settings.workspaces.empty
				onToggled: wanted => Settings.set("workspaces", "empty", wanted)
			}

			Setting {
				text: "The wheel the other way"
				subtext: "Up goes to the next one"
				checked: Settings.workspaces.reverse
				onToggled: wanted => Settings.set("workspaces", "reverse", wanted)
			}
		}
	}

	Component {
		id: batterySettings

		Column {
			spacing: Theme.u(10)

			Pick {
				text: "It shows"
				subtext: "How low is low is on the Session page"
				options: [
					{ value: "always", text: "Always" },
					{ value: "battery", text: "On battery" },
					{ value: "low", text: "When low" }
				]
				value: Settings.battery.show
				onChosen: value => Settings.set("battery", "show", value)
			}

			Pick {
				text: "Beside it"
				subtext: "The time, where it's known"
				options: [
					{ value: "percent", text: "Percent" },
					{ value: "time", text: "Time left" },
					{ value: "none", text: "Nothing" }
				]
				value: Settings.battery.label
				onChosen: value => Settings.set("battery", "label", value)
			}
		}
	}

	Component {
		id: elsewhereSettings

		Item {
			height: Theme.u(34)

			Note {
				anchors.left: parent.left
				anchors.right: opener.left
				anchors.rightMargin: Theme.u(12)
				anchors.verticalCenter: parent.verticalCenter
				text: `Its settings are on the ${page.elsewhere[page.chosen]} page.`
			}

			Button {
				id: opener

				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				height: Theme.u(30)
				text: "Open"
				onClicked: page.opens(page.elsewhere[page.chosen])
			}
		}
	}

	Component {
		id: nothingSettings

		Note {
			text: "Nothing to set for it yet."
		}
	}
}
