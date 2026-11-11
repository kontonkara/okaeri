import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The bar laid out: what's on its left, in its middle, on its right and what's
// off it. A part is dragged to where it goes, and the bar follows as it's let
// go; a click on one shows what it has to set, and under that what clicks and
// the wheel on it run. The control center stays on, and a bar on one screen: the
// way here goes through it. A part of the user's own is made here, a command
// whose words show on the bar. Under them what's for all of the bar, and the
// screens it's on.
Flickable {
	id: page

	readonly property var builtIn: ({
		battery: "Battery",
		bluetooth: "Bluetooth",
		cast: "Screen sharing",
		clipboard: "Clipboard",
		clock: "Clock",
		control: "Control center",
		keyboard: "Keyboard layout",
		media: "Media",
		network: "Network",
		notifications: "Notifications",
		privacy: "Microphone and camera",
		system: "System load",
		title: "Window title",
		tray: "Tray",
		units: "Failed units",
		workspaces: "Workspaces",
		// The newer ones last: the lanes show them in this order.
		recording: "Screen recording",
		locks: "Caps Lock",
		profile: "Power profile",
		awake: "Keep awake",
		night: "Night light"
	})
	// The user's own parts go by the names they have.
	readonly property var scripts: Settings.bar.scripts
	readonly property var names: {
		const all = Object.assign({}, builtIn);
		scripts.forEach(own => all[own.name] = all[own.name] ?? own.name);
		return all;
	}
	readonly property var buttons: [
		{ name: "left", text: "A click runs" },
		{ name: "right", text: "A right click" },
		{ name: "middle", text: "A middle click" },
		{ name: "up", text: "The wheel up" },
		{ name: "down", text: "The wheel down" }
	]
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
	// The part whose settings show, and the settings of those that have any here.
	property string chosen
	readonly property var partSettings: ({
			clock: clockSettings,
			workspaces: workspaceSettings,
			battery: batterySettings,
			media: mediaSettings,
			network: networkSettings,
			system: systemSettings,
			bluetooth: bluetoothSettings,
			locks: locksSettings,
			profile: profileSettings
		})
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
	// The media players open now, by name, and those left out that aren't.
	readonly property var players: {
		const there = [];
		Media.everyone.forEach(player => {
			if (!there.some(other => other.name === player.identity)) {
				const entry = DesktopEntries.heuristicLookup(player.desktopEntry || player.identity);
				there.push({ name: player.identity, icon: entry?.icon ? Quickshell.iconPath(entry.icon, true) : "", there: true });
			}
		});
		const gone = Settings.media.ignored.filter(name => !there.some(player => player.name === name)).map(name => ({ name, icon: "", there: false }));
		return there.concat(gone);
	}

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

	function ignore(name, wanted) {
		const others = Settings.media.ignored.filter(other => other !== name);
		Settings.set("media", "ignored", wanted ? others.concat([name]) : others);
	}

	// One more of the user's own, off the bar, with its settings up.
	function addScript() {
		let name = "script";
		for (let count = 2; names[name] !== undefined; count++)
			name = `script ${count}`;
		Settings.set("bar", "scripts", scripts.concat([{ name, command: "", every: 10 }]));
		chosen = name;
	}

	function changeScript(name, key, value) {
		Settings.set("bar", "scripts", scripts.map(own => own.name === name ? Object.assign({}, own, { [key]: value }) : own));
	}

	// By another name it keeps its place on the bar and its clicks. Not by none, nor
	// by one that's taken: false then.
	function renameScript(name, to) {
		if (to === name)
			return true;
		if (!to || names[to] !== undefined)
			return false;
		// The part first: the bar knows nothing by the new name before.
		changeScript(name, "name", to);
		["left", "center", "right"].filter(lane => Settings.bar[lane].includes(name)).forEach(lane => Settings.set("bar", lane, Settings.bar[lane].map(other => other === name ? to : other)));
		const actions = Object.assign({}, Settings.bar.actions);
		if (actions[name]) {
			actions[to] = actions[name];
			delete actions[name];
			Settings.set("bar", "actions", actions);
		}
		chosen = to;
		return true;
	}

	function removeScript(name) {
		["left", "center", "right"].filter(lane => Settings.bar[lane].includes(name)).forEach(lane => Settings.set("bar", lane, Settings.bar[lane].filter(other => other !== name)));
		runs(name, "", "");
		Settings.set("bar", "scripts", scripts.filter(own => own.name !== name));
		chosen = "";
	}

	// What `button` on `part` runs from now on: nothing with no command, and with
	// no button none of them does.
	function runs(part, button, command) {
		const actions = Object.assign({}, Settings.bar.actions);
		const own = button ? Object.assign({}, actions[part]) : {};
		if (command)
			own[button] = command;
		else
			delete own[button];
		if (Object.keys(own).length > 0)
			actions[part] = own;
		else
			delete actions[part];
		if (JSON.stringify(actions) !== JSON.stringify(Settings.bar.actions))
			Settings.set("bar", "actions", actions);
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

				Item {
					width: parent.width
					height: Math.max(about.height, adding.height)

					Note {
						id: about

						width: parent.width - adding.width - Theme.u(12)
						text: "A click on a part shows its settings, and under them what clicks and the wheel on it run. Media, Bluetooth, Microphone and camera, Screen recording, Screen sharing, Failed units, Keyboard layout and Caps Lock show only when they have something to say."
					}

					Button {
						id: adding

						anchors.right: parent.right
						height: Theme.u(30)
						text: "Add your own"
						tip: "A part that shows what a command prints"
						onClicked: page.addScript()
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
				sourceComponent: page.partSettings[page.chosen] ?? (page.elsewhere[page.chosen] ? elsewhereSettings : page.builtIn[page.chosen] ? nothingSettings : scriptSettings)
			}
		}

		// The tray's icons are apps, with clicks of their own.
		Card {
			id: clicks

			width: parent.width
			visible: page.chosen !== "" && page.chosen !== "tray"
			title: visible ? "Clicks and the wheel on it" : ""

			// Anew for another part: what was typed and not kept goes.
			Repeater {
				model: clicks.visible ? [page.chosen] : []

				Column {
					id: commands

					required property string modelData
					readonly property var kept: Settings.bar.actions[modelData] ?? ({})

					width: parent.width
					spacing: Theme.u(10)

					Repeater {
						model: page.buttons

						Field {
							required property var modelData

							text: modelData.text
							placeholder: "A command"
							value: commands.kept[modelData.name] ?? ""
							onKept: value => page.runs(commands.modelData, modelData.name, value)
						}
					}

					Note {
						text: "A command, kept with Enter, takes the place of what the part does with that button, or with the wheel. Emptied, the part has it back."
					}
				}
			}
		}

		Card {
			width: parent.width
			title: "All of the bar"

			Pick {
				text: "It's at"
				subtext: "And its panels with it"
				options: [
					{ value: "top", text: "The top" },
					{ value: "bottom", text: "The bottom" }
				]
				value: Settings.bar.position
				onChosen: value => Settings.set("bar", "position", value)
			}

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

			Setting {
				text: "It hides"
				subtext: "Until the pointer rests at the top of the screen, or a panel opens"
				checked: Settings.bar.autoHide
				onToggled: wanted => Settings.set("bar", "autoHide", wanted)
			}

			Setting {
				text: "Windows keep out from under it"
				subtext: "Off, they take the whole screen, and the bar is over them"
				checked: Settings.bar.reserve
				// A bar that hides keeps no space.
				enabled: !Settings.bar.autoHide
				onToggled: wanted => Settings.set("bar", "reserve", wanted)
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

			Pick {
				text: "Weeks start on"
				subtext: "In the month a click on it shows"
				options: [
					{ value: "locale", text: "As here" },
					{ value: "monday", text: "Monday" },
					{ value: "sunday", text: "Sunday" }
				]
				value: Settings.clock.weekStart
				onChosen: value => Settings.set("clock", "weekStart", value)
			}

			Setting {
				text: "Week numbers"
				checked: Settings.clock.weekNumbers
				onToggled: wanted => Settings.set("clock", "weekNumbers", wanted)
			}

			Field {
				text: "Other places"
				subtext: "Their time, over the month: Europe/Berlin, Asia/Tokyo"
				placeholder: "Zones, with commas"
				value: Settings.clock.zones.join(", ")
				onKept: value => Settings.set("clock", "zones", value.split(",").map(zone => zone.trim()).filter(zone => zone !== ""))
			}

			Setting {
				text: "The weather"
				subtext: "Over the month, from open-meteo.com"
				checked: Settings.weather.on
				onToggled: wanted => Settings.set("weather", "on", wanted)
			}

			Item {
				id: place

				// What came of the last name typed, and whether it's still being looked for.
				property string said: ""
				property bool looking: false

				width: parent.width
				height: Theme.u(40)
				visible: Settings.weather.on

				Connections {
					target: Weather

					function onLocated(name) {
						place.looking = false;
						place.said = "";
					}

					function onNotFound(why) {
						place.looking = false;
						place.said = why;
					}
				}

				Column {
					anchors.left: parent.left
					anchors.right: where.left
					anchors.rightMargin: Theme.u(12)
					anchors.verticalCenter: parent.verticalCenter

					Text {
						width: parent.width
						text: "Where"
						color: Theme.colors.text
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Text {
						width: parent.width
						text: place.looking ? "Looking for it" : place.said || Settings.weather.place || "A town's name, Enter to look for it"
						textFormat: Text.PlainText
						color: place.said ? Theme.colors.error : Theme.colors.subtext
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize - Theme.u(2)
					}
				}

				TextField {
					id: where

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					implicitWidth: Theme.u(170)
					implicitHeight: Theme.u(32)
					placeholder: "Berlin"
					onAccepted: {
						if (text.trim() !== "") {
							place.looking = true;
							Weather.locate(text.trim());
						}
					}
				}
			}

			Pick {
				text: "In"
				visible: Settings.weather.on
				options: [
					{ value: "celsius", text: "°C" },
					{ value: "fahrenheit", text: "°F" }
				]
				value: Settings.weather.units
				onChosen: value => Settings.set("weather", "units", value)
			}

			Setting {
				text: "Beside the time"
				subtext: "How warm it is"
				visible: Settings.weather.on
				checked: Settings.weather.bar
				onToggled: wanted => Settings.set("weather", "bar", wanted)
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
				text: "The apps on each"
				subtext: "Their icons: a click on one goes to its window"
				checked: Settings.workspaces.apps
				onToggled: wanted => Settings.set("workspaces", "apps", wanted)
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
		id: mediaSettings

		Column {
			spacing: Theme.u(10)

			Pick {
				text: "It shows"
				options: [
					{ value: "player", text: "With a player" },
					{ value: "playing", text: "While it plays" }
				]
				value: Settings.media.show
				onChosen: value => Settings.set("media", "show", value)
			}

			Pick {
				text: "On it"
				options: [
					{ value: "title", text: "The title" },
					{ value: "both", text: "Artist, title" },
					{ value: "none", text: "Only the icon" }
				]
				value: Settings.media.label
				onChosen: value => Settings.set("media", "label", value)
			}

			Choice {
				text: "Widest"
				subtext: "Past that the title is cut"
				visible: Settings.media.label !== "none"
				values: [120, 160, 200, 280, 360]
				value: Settings.media.width
				unit: " px"
				onChosen: value => Settings.set("media", "width", value)
			}

			Setting {
				text: "What's cut slides by"
				subtext: "Under the pointer, to its end and back"
				visible: Settings.media.label !== "none"
				checked: Settings.media.scroll
				onToggled: wanted => Settings.set("media", "scroll", wanted)
			}

			Note {
				text: page.players.length > 0 ? "Players: one turned off is left out of the bar, its card and the media keys." : "Players show here as they open."
			}

			Repeater {
				model: page.players

				Setting {
					required property var modelData

					text: modelData.name
					subtext: modelData.there ? "" : "Not open now"
					image: modelData.icon
					checked: !Settings.media.ignored.includes(modelData.name)
					onToggled: wanted => page.ignore(modelData.name, !wanted)
				}
			}
		}
	}

	Component {
		id: systemSettings

		Column {
			spacing: Theme.u(10)

			Setting {
				text: "The processor"
				subtext: "How busy it is"
				checked: Settings.system.cpu
				onToggled: wanted => Settings.set("system", "cpu", wanted)
			}

			Setting {
				text: "Memory"
				subtext: "How much is in use"
				checked: Settings.system.memory
				onToggled: wanted => Settings.set("system", "memory", wanted)
			}

			Setting {
				text: "Temperature"
				subtext: "The processor's, where it has a sensor"
				checked: Settings.system.temperature
				onToggled: wanted => Settings.set("system", "temperature", wanted)
			}

			Setting {
				text: "The network"
				subtext: "How fast it comes in and goes out"
				checked: Settings.system.network
				onToggled: wanted => Settings.set("system", "network", wanted)
			}

			Choice {
				text: "Read every"
				values: [1, 2, 5, 10]
				value: Settings.system.interval
				onChosen: value => Settings.set("system", "interval", value)
			}
		}
	}

	Component {
		id: networkSettings

		Pick {
			text: "Beside it"
			options: [
				{ value: "none", text: "Nothing" },
				{ value: "name", text: "The network" }
			]
			value: Settings.network.label
			onChosen: value => Settings.set("network", "label", value)
		}
	}

	Component {
		id: bluetoothSettings

		Column {
			spacing: Theme.u(10)

			Pick {
				text: "It shows"
				options: [
					{ value: "connected", text: "With a device" },
					{ value: "on", text: "While it's on" }
				]
				value: Settings.bluetooth.show
				onChosen: value => Settings.set("bluetooth", "show", value)
			}

			Pick {
				text: "Beside it"
				options: [
					{ value: "none", text: "Nothing" },
					{ value: "name", text: "The device" }
				]
				value: Settings.bluetooth.label
				onChosen: value => Settings.set("bluetooth", "label", value)
			}
		}
	}

	Component {
		id: locksSettings

		Pick {
			text: "It shows for"
			subtext: "While that's on"
			options: [
				{ value: "caps", text: "Caps Lock" },
				{ value: "both", text: "Num Lock too" }
			]
			value: Settings.locks.show
			onChosen: value => Settings.set("locks", "show", value)
		}
	}

	Component {
		id: profileSettings

		Pick {
			text: "Beside it"
			options: [
				{ value: "none", text: "Nothing" },
				{ value: "name", text: "Its name" }
			]
			value: Settings.profile.label
			onChosen: value => Settings.set("profile", "label", value)
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
		id: scriptSettings

		Column {
			// Anew for another part: what was typed and not kept goes.
			Repeater {
				model: [page.chosen]

				Column {
					id: script

					required property string modelData
					readonly property var own: page.scripts.find(other => other.name === modelData) ?? ({})
					// A name it couldn't take.
					property bool refused: false

					width: parent.width
					spacing: Theme.u(10)

					Field {
						text: "What it's called"
						subtext: script.refused ? "A part goes by that name" : "On the lanes above, and in the config"
						value: script.modelData
						onKept: value => script.refused = !page.renameScript(script.modelData, value)
					}

					Field {
						text: "Its command"
						subtext: "For sh, Enter to keep"
						placeholder: "date +%A"
						value: script.own.command ?? ""
						onKept: value => page.changeScript(script.modelData, "command", value)
					}

					Choice {
						text: "It runs every"
						subtext: "Once, each line it goes on to print is shown in turn"
						values: [0, 1, 2, 5, 10, 30, 60, 300, 900, 3600]
						value: script.own.every ?? 0
						none: "Once"
						onChosen: value => page.changeScript(script.modelData, "every", value)
					}

					Note {
						text: "The first line it prints shows, and the second is what the pointer on it says; or a line of JSON as for waybar, with text, tooltip and class. With nothing printed the part isn't there."
					}

					Button {
						height: Theme.u(30)
						text: "Remove it"
						onClicked: page.removeScript(script.modelData)
					}
				}
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
