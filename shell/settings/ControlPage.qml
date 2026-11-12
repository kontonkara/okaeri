import QtQuick
import Quickshell
import qs
import qs.control
import qs.ui

// The control center's tiles as they're laid out: one is dragged to where it
// goes, or to Hidden to leave it out, and the panel follows as it's let go. A
// click on one shows its width: half a row, or a whole one. One left alone in
// its row takes all of it either way. What doesn't apply here doesn't show in
// the panel either way. A tile of the user's own is made here: a command for a
// click, and one that says whether it's on.
Flickable {
	id: page

	readonly property var builtIn: ({
			wifi: "Wi-Fi",
			bluetooth: "Bluetooth",
			night: "Night light",
			awake: "Keep awake",
			power: "Power profile",
			airplane: "Airplane mode",
			vpn: "VPN",
			record: "Screen recording"
		})
	// The user's own go by the names they have.
	readonly property var custom: Settings.control.custom
	readonly property var names: {
		const all = Object.assign({}, builtIn);
		custom.forEach(own => all[own.name] = all[own.name] ?? own.name);
		return all;
	}
	readonly property bool own: chosen !== "" && builtIn[chosen] === undefined
	readonly property var signs: Object.keys(Theme.icons).map(name => ({ value: name, text: name }))
	readonly property var lanes: [
		{ name: "shown", text: "Tiles" },
		{ name: "hidden", text: "Hidden" }
	]
	readonly property var settled: ({
			shown: Control.order.filter(name => !Settings.control.hidden.includes(name)),
			hidden: Control.order.filter(name => Settings.control.hidden.includes(name))
		})
	// The tile being dragged, and how things would be if it were let go now.
	property string held
	property var moved: null
	readonly property var shown: moved ?? settled
	readonly property var whole: Control.whole(shown.shown)
	// The tile whose width shows.
	property string chosen

	function chipAt(x, y) {
		for (let index = 0; index < rows.count; index++) {
			const flow = rows.itemAt(index).flow;
			const at = flow.mapFromItem(board, x, y);
			const chip = flow.childAt(at.x, at.y);
			if (chip && chip.name)
				return chip;
		}
		return null;
	}

	// The held tile goes where the pointer is, among what's there. Outside the
	// lanes it stays where it last was.
	function place(x, y) {
		for (let index = 0; index < rows.count; index++) {
			const lane = rows.itemAt(index);
			if (!lane.contains(lane.mapFromItem(board, x, y)))
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
			Settings.set("control", "tiles", moved.shown.concat(moved.hidden));
			Settings.set("control", "hidden", moved.hidden);
		}
		held = "";
		moved = null;
	}

	// One more of the user's own, with its card up.
	function add() {
		let name = "Mine";
		for (let count = 2; names[name] !== undefined; count++)
			name = `Mine ${count}`;
		Settings.set("control", "custom", custom.concat([{ name, command: "", check: "", icon: "play" }]));
		chosen = name;
	}

	function change(name, key, value) {
		Settings.set("control", "custom", custom.map(own => own.name === name ? Object.assign({}, own, { [key]: value }) : own));
	}

	// By another name it keeps its place, its width and whether it's hidden. Not
	// by none, nor by one that's taken: false then.
	function rename(name, to) {
		if (to === name)
			return true;
		if (!to || names[to] !== undefined)
			return false;
		const order = Control.order;
		change(name, "name", to);
		["tiles", "wide", "hidden"].forEach(key => Settings.set("control", key, (key === "tiles" ? order : Settings.control[key]).map(other => other === name ? to : other)));
		chosen = to;
		return true;
	}

	function remove(name) {
		["tiles", "wide", "hidden"].forEach(key => Settings.set("control", key, Settings.control[key].filter(other => other !== name)));
		Settings.set("control", "custom", custom.filter(own => own.name !== name));
		chosen = "";
	}

	function widen(name, wanted) {
		const others = Settings.control.wide.filter(other => other !== name);
		Settings.set("control", "wide", wanted ? others.concat([name]) : others);
	}

	contentHeight: stack.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	component Chip: Rectangle {
		property string name
		property string text: page.names[name] ?? name
		// For the search: a tile is found by its name, as a line is.
		readonly property string subtext: ""
		property color ink: Theme.colors.text

		height: Theme.u(38)
		radius: Math.max(0, Theme.cardRadius - Theme.u(4))
		color: Qt.alpha(Theme.colors.text, 0.1)

		Text {
			anchors.centerIn: parent
			width: parent.width - Theme.u(16)
			horizontalAlignment: Text.AlignHCenter
			text: parent.text
			textFormat: Text.PlainText
			elide: Text.ElideRight
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
		view: page
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
							// What's below shouldn't move as a tile comes in.
							height: Math.max(implicitHeight, Theme.u(38))
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

								// As wide as on the panel; out of it, as its name.
								Chip {
									required property string modelData

									name: modelData
									width: lane.name === "hidden" ? Theme.u(140) : page.whole[name] ? chips.width : (chips.width - chips.spacing) / 2
									color: name === page.chosen ? Qt.alpha(Theme.colors.accent, 0.3) : Qt.alpha(Theme.colors.text, 0.1)
									opacity: name === page.held ? 0.3 : 1
								}
							}
						}
					}
				}

				Item {
					width: parent.width
					height: Math.max(about.height, adding.height)

					Note {
						id: about

						width: parent.width - adding.width - Theme.u(12)
						text: "A tile is dragged to where it goes, or to Hidden to leave it out, and a click on one shows its width. Wi-Fi, Bluetooth, the power profile, airplane mode, VPN and the screen recording show only where the machine has them."
					}

					Button {
						id: adding

						anchors.right: parent.right
						height: Theme.u(30)
						text: "Add your own"
						tip: "A tile that runs a command"
						onClicked: page.add()
					}
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
				name: page.held
				color: Theme.colors.accent
				ink: Theme.colors.background
			}
		}

		Card {
			width: parent.width
			visible: page.chosen !== ""
			title: page.names[page.chosen] ?? page.chosen

			Pick {
				text: "Its width"
				subtext: "Alone in its row, it takes all of it either way"
				options: [
					{ value: false, text: "Half a row" },
					{ value: true, text: "A whole row" }
				]
				value: Settings.control.wide.includes(page.chosen)
				onChosen: value => page.widen(page.chosen, value)
			}

			// Anew for another tile: what was typed and not kept goes.
			Repeater {
				model: page.own ? [page.chosen] : []

				Column {
					id: tile

					required property string modelData
					readonly property var its: page.custom.find(other => other.name === modelData) ?? ({})
					// A name it couldn't take.
					property bool refused: false

					width: parent.width
					spacing: Theme.u(10)

					Field {
						text: "What it's called"
						subtext: tile.refused ? "A tile goes by that name" : "On the tile"
						value: tile.modelData
						onKept: value => tile.refused = !page.rename(tile.modelData, value)
					}

					Field {
						text: "A click runs"
						subtext: "For sh: OKAERI_ON is 1 with the tile on"
						placeholder: "A command"
						value: tile.its.command ?? ""
						onKept: value => page.change(tile.modelData, "command", value)
					}

					Field {
						text: "It's on when"
						subtext: "Its command ends well then: with none it's a button"
						placeholder: "A command"
						value: tile.its.check ?? ""
						onKept: value => page.change(tile.modelData, "check", value)
					}

					Pick {
						text: "Its sign"
						options: page.signs
						value: tile.its.icon ?? "play"
						onChosen: value => page.change(tile.modelData, "icon", value)
					}

					Button {
						height: Theme.u(30)
						text: "Remove it"
						onClicked: page.remove(tile.modelData)
					}
				}
			}
		}
	}
}
