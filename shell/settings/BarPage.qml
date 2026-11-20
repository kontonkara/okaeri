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
		title: Tr.t("Window title"),
		tray: "Tray",
		units: "Failed units",
		workspaces: "Workspaces",
		// The newer ones last: the lanes show them in this order.
		recording: "Screen recording",
		locks: "Caps Lock",
		profile: "Power profile",
		awake: "Keep awake",
		night: "Night light",
		volume: "Volume",
		launcher: "Launcher",
		notes: "Notes and things to do",
		visualizer: "Sound bars",
		updates: "Updates"
	})
	// The user's own parts go by the names they have, and plugins' by their folders'
	// names, shown by what they call themselves.
	readonly property var scripts: Settings.bar.scripts
	readonly property var names: {
		const all = Object.assign({}, builtIn);
		scripts.forEach(own => all[own.name] = all[own.name] ?? own.name);
		Plugins.running.filter(plugin => plugin.bar !== "").forEach(plugin => all[plugin.id] = all[plugin.id] ?? plugin.name);
		// Separators and spaces: those on a bar, and one more of each to put there.
		const lanes = ["left", "center", "right"];
		const on = [];
		[Settings.bar].concat(Object.values(Settings.bar.screens ?? {})).forEach(own => lanes.forEach(lane => (own[lane] ?? []).forEach(name => on.push(name))));
		[{ kind: "separator", text: "Separator" }, { kind: "space", text: "Space" }].forEach(spacer => {
			on.filter(name => Settings.spacer(name) && name.startsWith(spacer.kind)).forEach(name => all[name] = spacer.text);
			let spare = spacer.kind;
			for (let count = 2; all[spare] !== undefined; count++)
				spare = `${spacer.kind} ${count}`;
			all[spare] = spacer.text;
		});
		return all;
	}
	readonly property var buttons: [
		{ name: "left", text: Tr.t("A click runs") },
		{ name: "right", text: Tr.t("A right click") },
		{ name: "middle", text: Tr.t("A middle click") },
		{ name: "up", text: Tr.t("The wheel up") },
		{ name: "down", text: Tr.t("The wheel down") }
	]
	// Those whose settings are on a page of their own, by its name.
	readonly property var elsewhere: ({
		clipboard: "Clipboard",
		control: "Control center",
		launcher: "Launcher",
		notifications: "Notifications",
		tray: "Tray"
	})
	readonly property var lanes: [
		{ name: "left", text: Settings.barSide ? "Top" : "Left" },
		{ name: "center", text: Tr.t("Middle") },
		{ name: "right", text: Settings.barSide ? "Bottom" : "Right" },
		{ name: "off", text: Tr.t("Not on the bar") }
	]
	// The bar whose lanes show: a screen's, by its name, or with "" every screen's.
	// A screen picked has lanes of its own from the first change to them.
	property string forScreen: ""
	readonly property var barScreens: [...new Set(Quickshell.screens.map(screen => screen.name).concat(Object.keys(Settings.bar.screens ?? {})))]
	readonly property var settled: {
		const left = Settings.laneOf(forScreen, "left");
		const center = Settings.laneOf(forScreen, "center");
		const right = Settings.laneOf(forScreen, "right");
		const on = left.concat(center, right);
		return {
			left,
			center,
			right,
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
			visualizer: visualizerSettings,
			updates: updatesSettings,
			profile: profileSettings,
			volume: volumeSettings,
			recording: recordingSettings
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
			["left", "center", "right"].filter(lane => moved[lane].join() !== Settings.laneOf(forScreen, lane).join()).forEach(lane => Settings.setLane(forScreen, lane, moved[lane]));
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
		if (!to || names[to] !== undefined || Settings.spacer(to))
			return false;
		// The part first: the bar knows nothing by the new name before.
		changeScript(name, "name", to);
		Settings.eachLane(parts => parts.map(other => other === name ? to : other));
		const actions = Object.assign({}, Settings.bar.actions);
		if (actions[name]) {
			actions[to] = actions[name];
			delete actions[name];
			Settings.set("bar", "actions", actions);
		}
		if (Settings.bar.looks[name]) {
			const looks = Object.assign({}, Settings.bar.looks, { [to]: Settings.bar.looks[name] });
			delete looks[name];
			Settings.set("bar", "looks", looks);
		}
		chosen = to;
		return true;
	}

	function removeScript(name) {
		Settings.eachLane(parts => parts.filter(other => other !== name));
		runs(name, "", "");
		setLook(name, "", "");
		Settings.set("bar", "scripts", scripts.filter(own => own.name !== name));
		chosen = "";
	}

	// One more calendar under the month: false for what isn't a file by its whole
	// path or an address. One that's there already stays where it is.
	function addCalendar(source) {
		if (!Events.takes(source))
			return false;
		if (!Events.sources.includes(source))
			Settings.set("clock", "calendars", Events.sources.concat([source]));
		return true;
	}

	function removeCalendar(source) {
		Settings.set("clock", "calendars", Events.sources.filter(other => other !== source));
	}

	// The look of `part`, Settings.bar.looks, with `key` as `value`: none of its
	// own with "", and with no key none of it.
	function setLook(part, key, value) {
		const looks = Object.assign({}, Settings.bar.looks);
		const own = key ? Object.assign({}, looks[part]) : {};
		if (value === "" || value === undefined)
			delete own[key];
		else
			own[key] = value;
		if (Object.keys(own).length > 0)
			looks[part] = own;
		else
			delete looks[part];
		if (JSON.stringify(looks) !== JSON.stringify(Settings.bar.looks))
			Settings.set("bar", "looks", looks);
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

		// With more screens than one, each bar can have lanes of its own.
		Item {
			width: parent.width
			height: whichBar.height
			visible: page.barScreens.length > 1 || Object.keys(Settings.bar.screens ?? {}).length > 0

			Pick {
				id: whichBar

				holds: "bar.screens"
				words: "monitor screen several bars"
				width: parent.width - (alike.visible ? alike.width + Theme.u(8) : 0)
				text: Tr.t("The bar of")
				subtext: page.forScreen && !Settings.bar.screens?.[page.forScreen] ? Tr.t("It has every screen's, till a part moves") : ""
				options: [{ value: "", text: Tr.t("Every screen") }].concat(page.barScreens.map(name => ({ value: name, text: name })))
				value: page.forScreen
				onChosen: value => page.forScreen = value
			}

			Button {
				id: alike

				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				height: Theme.u(30)
				visible: page.forScreen !== "" && !!Settings.bar.screens?.[page.forScreen]
				flat: true
				text: Tr.t("Like the others")
				onClicked: Settings.dropLanes(page.forScreen)
			}
		}

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
						title: Tr.t(modelData.text)

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
									duration: Theme.ms(120)
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

									text: Tr.t(page.names[name] ?? name)
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
						text: Tr.t("A click on a part shows its settings, and under them what clicks and the wheel on it run. Media, Bluetooth, Microphone and camera, Screen recording, Screen sharing, Failed units, Keyboard layout and Caps Lock show only when they have something to say.")
					}

					Button {
						id: adding

						anchors.right: parent.right
						height: Theme.u(30)
						text: Tr.t("Add your own")
						tip: Tr.t("A part that shows what a command prints")
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
				text: Tr.t(page.names[page.held] ?? page.held)
				color: Theme.colors.accent
				ink: Theme.colors.background
			}
		}

		Card {
			id: part

			width: parent.width
			visible: page.chosen !== ""
			title: Tr.t(page.names[page.chosen] ?? page.chosen)

			Loader {
				width: parent.width
				sourceComponent: page.partSettings[page.chosen] ?? (page.elsewhere[page.chosen] ? elsewhereSettings : Settings.spacer(page.chosen) ? spacerSettings : page.builtIn[page.chosen] ? nothingSettings : scriptSettings)
			}
		}

		// Its capsule and its colors, over what the bar's look gives every part.
		Card {
			id: looks

			readonly property var own: Settings.bar.looks[page.chosen] ?? ({})
			readonly property bool capsule: own.capsule ?? (Settings.bar.look === "capsules" && !Settings.spacer(page.chosen))

			width: parent.width
			visible: page.chosen !== ""
			title: visible ? Tr.t("How it looks") : ""

			Pick {
				holds: "bar.looks"
				words: "capsule pill background shape"
				visible: !page.chosen.startsWith("space")
				text: Tr.t("A capsule")
				subtext: looks.own.capsule === undefined ? Tr.t("As the bar's look has it, on the Look page") : ""
				options: [
					{ value: "", text: Tr.t("As the bar") },
					{ value: "on", text: Tr.t("Its own") },
					{ value: "off", text: Tr.t("None") }
				]
				value: looks.own.capsule === undefined ? "" : looks.own.capsule ? "on" : "off"
				onChosen: value => page.setLook(page.chosen, "capsule", value === "" ? "" : value === "on")
			}

			Shade {
				holds: "bar.looks"
				words: "capsule background colour color"
				visible: looks.capsule
				text: Tr.t("Its fill")
				none: Settings.bar.look === "capsules" ? Theme.barFill : Theme.hover
				value: looks.own.fill ?? ""
				onChosen: value => page.setLook(page.chosen, "fill", value)
			}

			Shade {
				holds: "bar.looks"
				words: "icon text foreground colour color"
				visible: !page.chosen.startsWith("space")
				text: Tr.t("Its icons and words")
				subtext: Tr.t("The accent and the warnings keep theirs")
				value: looks.own.ink ?? ""
				onChosen: value => page.setLook(page.chosen, "ink", value)
			}

			Button {
				visible: Object.keys(looks.own).length > 0
				height: Theme.u(30)
				flat: true
				text: Tr.t("As the theme")
				onClicked: page.setLook(page.chosen, "", "")
			}
		}

		// The tray's icons are apps, with clicks of their own.
		Card {
			id: clicks

			width: parent.width
			visible: page.chosen !== "" && page.chosen !== "tray" && !Settings.spacer(page.chosen)
			title: visible ? Tr.t("Clicks and the wheel on it") : ""

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
							placeholder: Tr.t("A command")
							value: commands.kept[modelData.name] ?? ""
							onKept: value => page.runs(commands.modelData, modelData.name, value)
						}
					}

					Note {
						text: Tr.t("A command, kept with Enter, takes the place of what the part does with that button, or with the wheel. Emptied, the part has it back.")
					}
				}
			}
		}

		Card {
			width: parent.width
			title: Tr.t("All of the bar")

			Pick {
				holds: "bar.position"
				text: Tr.t("It's at")
				subtext: Settings.barSide ? Tr.t("Upright, its parts one under another") : Tr.t("And its panels with it")
				options: [
					{ value: "top", text: Tr.t("The top") },
					{ value: "bottom", text: Tr.t("The bottom") },
					{ value: "left", text: Tr.t("The left") },
					{ value: "right", text: Tr.t("The right") }
				]
				value: Settings.bar.position
				onChosen: value => Settings.set("bar", "position", value)
			}

			Pick {
				holds: "bar.wheel"
				text: Tr.t("The wheel on it")
				subtext: Settings.bar.wheel === "split" ? Tr.t("Brightness on the left half, volume on the right") : Tr.t("Where no part takes it")
				options: [
					{ value: "split", text: Tr.t("Split") },
					{ value: "volume", text: Tr.t("Volume") },
					{ value: "brightness", text: Tr.t("Brightness") },
					{ value: "workspaces", text: Tr.t("Workspaces") },
					{ value: "none", text: Tr.t("Nothing") }
				]
				value: Settings.bar.wheel
				onChosen: value => Settings.set("bar", "wheel", value)
			}

			Setting {
				holds: "bar.tips"
				text: Tr.t("Tips")
				subtext: Tr.t("What a part is or says, under the pointer")
				checked: Settings.bar.tips
				onToggled: wanted => Settings.set("bar", "tips", wanted)
			}

			Pick {
				holds: "bar.overWindows"
				words: "windows dodge intellihide solid opaque"
				text: Tr.t("With windows on the workspace")
				subtext: Settings.bar.overWindows === "solid" ? Tr.t("Solid, without its glass; with none, as it was") : Settings.bar.overWindows === "hide" ? Tr.t("It hides, as if it always did; with none it's there") : Tr.t("The same with windows or without")
				options: [
					{ value: "same", text: Tr.t("As it is") },
					{ value: "solid", text: Tr.t("Solid") },
					{ value: "hide", text: Tr.t("Out of the way") }
				]
				value: Settings.bar.overWindows
				valueWidth: Theme.u(140)
				onChosen: value => Settings.set("bar", "overWindows", value)
			}

			Setting {
				holds: "bar.hoverOpens"
				words: "hover pointer open"
				text: Tr.t("The pointer opens panels")
				subtext: Tr.t("Resting on the clock, the battery, the media, the load, the notes, the notifications or the control center")
				checked: Settings.bar.hoverOpens
				onToggled: wanted => Settings.set("bar", "hoverOpens", wanted)
			}

			Setting {
				holds: "bar.hoverCloses"
				words: "hover pointer close leave"
				enabled: Settings.bar.hoverOpens
				text: Tr.t("And closes them as it leaves")
				subtext: Tr.t("A panel it opened goes once the pointer is off both it and the part")
				checked: Settings.bar.hoverCloses
				onToggled: wanted => Settings.set("bar", "hoverCloses", wanted)
			}

			Setting {
				holds: "bar.autoHide"
				text: Tr.t("It hides")
				subtext: Tr.t("Until the pointer rests at the top of the screen, or a panel opens")
				checked: Settings.bar.autoHide
				onToggled: wanted => Settings.set("bar", "autoHide", wanted)
			}

			Setting {
				holds: "bar.reserve"
				text: Tr.t("Windows keep out from under it")
				subtext: Tr.t("Off, they take the whole screen, and the bar is over them")
				checked: Settings.bar.reserve
				// A bar that hides keeps no space.
				enabled: !Settings.bar.autoHide
				onToggled: wanted => Settings.set("bar", "reserve", wanted)
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Screens")

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
				holds: "clock.date"
				text: Tr.t("The date")
				subtext: Tr.t("Beside the time")
				options: [
					{ value: "before", text: Tr.t("Before") },
					{ value: "after", text: Tr.t("After") },
					{ value: "none", text: Tr.t("None") }
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
						text: Tr.t("How it's written")
						color: Theme.colors.text
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Text {
						width: parent.width
						text: Tr.t("In Qt's letters: ddd d MMM is Sat 7 Nov")
						color: Theme.colors.subtext
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize - Theme.u(2)
					}
				}

				TextField {
					id: format

					objectName: "field"
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					implicitWidth: Theme.u(170)
					implicitHeight: Theme.u(32)
					placeholder: "ddd d MMM"
					text: Settings.clock.dateFormat
					keeps: true
					onAccepted: Settings.set("clock", "dateFormat", text.trim())
				}
			}

			Setting {
				holds: "clock.hours12"
				text: "12-hour time"
				subtext: Tr.t("With AM and PM")
				checked: Settings.clock.hours12
				onToggled: wanted => Settings.set("clock", "hours12", wanted)
			}

			Setting {
				holds: "clock.seconds"
				text: Tr.t("Seconds")
				checked: Settings.clock.seconds
				onToggled: wanted => Settings.set("clock", "seconds", wanted)
			}

			Pick {
				holds: "clock.weekStart"
				text: Tr.t("Weeks start on")
				subtext: Tr.t("In the month a click on it shows")
				options: [
					{ value: "locale", text: Tr.t("As here") },
					{ value: "monday", text: Tr.t("Monday") },
					{ value: "sunday", text: Tr.t("Sunday") }
				]
				value: Settings.clock.weekStart
				onChosen: value => Settings.set("clock", "weekStart", value)
			}

			Setting {
				holds: "clock.weekNumbers"
				text: Tr.t("Week numbers")
				checked: Settings.clock.weekNumbers
				onToggled: wanted => Settings.set("clock", "weekNumbers", wanted)
			}

			Field {
				holds: "clock.zones"
				text: Tr.t("Other places")
				subtext: Tr.t("Their time, over the month: Europe/Berlin, Asia/Tokyo")
				placeholder: Tr.t("Zones, with commas")
				value: Settings.clock.zones.join(", ")
				onKept: value => Settings.set("clock", "zones", value.split(",").map(zone => zone.trim()).filter(zone => zone !== ""))
			}

			Setting {
				holds: "weather.on"
				text: Tr.t("The weather")
				subtext: Tr.t("Over the month, from open-meteo.com")
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
						text: Tr.t("Where")
						color: Theme.colors.text
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Text {
						width: parent.width
						text: place.looking ? Tr.t("Looking for it") : place.said || Settings.weather.place || Tr.t("A town's name, Enter to look for it")
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
					placeholder: Tr.t("Berlin")
					onAccepted: {
						if (text.trim() !== "") {
							place.looking = true;
							Weather.locate(text.trim());
						}
					}
				}
			}

			Pick {
				holds: "weather.units"
				text: Tr.t("In")
				visible: Settings.weather.on
				options: [
					{ value: "celsius", text: "°C" },
					{ value: "fahrenheit", text: "°F" }
				]
				value: Settings.weather.units
				onChosen: value => Settings.set("weather", "units", value)
			}

			Setting {
				holds: "weather.bar"
				text: Tr.t("Beside the time")
				subtext: Tr.t("How warm it is")
				visible: Settings.weather.on
				checked: Settings.weather.bar
				onToggled: wanted => Settings.set("weather", "bar", wanted)
			}

			Choice {
				holds: "clock.remind"
				words: "reminder notification event"
				text: Tr.t("Say that an event is coming")
				subtext: Tr.t("That long before one with a time starts")
				visible: Events.on
				values: [0, 300, 600, 900, 1800, 3600]
				value: Settings.clock.remind * 60
				onChosen: value => Settings.set("clock", "remind", value / 60)
			}

			Choice {
				holds: "pomodoro.work"
				words: "pomodoro focus timer"
				text: Tr.t("A pomodoro's work")
				subtext: Tr.t("From the clock's card, then a break")
				values: [15, 20, 25, 30, 45, 50, 60]
				unit: "min"
				value: Settings.pomodoro.work
				onChosen: value => Settings.set("pomodoro", "work", value)
			}

			Choice {
				holds: "pomodoro.pause"
				words: "pomodoro break"
				text: Tr.t("Its break")
				values: [3, 5, 10, 15]
				unit: "min"
				value: Settings.pomodoro.pause
				onChosen: value => Settings.set("pomodoro", "pause", value)
			}

			Choice {
				holds: "pomodoro.long"
				words: "pomodoro break"
				text: Tr.t("A long break")
				values: [10, 15, 20, 30]
				unit: "min"
				value: Settings.pomodoro.long
				onChosen: value => Settings.set("pomodoro", "long", value)
			}

			Choice {
				holds: "pomodoro.rounds"
				words: "pomodoro"
				text: Tr.t("After how many works")
				subtext: Tr.t("The long break")
				values: [2, 3, 4, 5, 6]
				value: Settings.pomodoro.rounds
				onChosen: value => Settings.set("pomodoro", "rounds", value)
			}

			// The calendars whose events the month has, and a field for one more. What a
			// calendar can be is said under the field's name rather than in a note of its
			// own, so that with none the card grows by that one row.
			Repeater {
				model: Events.sources

				Item {
					id: calendarRow

					required property string modelData

					width: parent.width
					height: Theme.u(40)

					Column {
						anchors.left: parent.left
						anchors.right: calendarDrop.left
						anchors.rightMargin: Theme.u(12)
						anchors.verticalCenter: parent.verticalCenter

						Text {
							width: parent.width
							text: Events.title(calendarRow.modelData)
							textFormat: Text.PlainText
							color: Theme.colors.text
							elide: Text.ElideMiddle
							font.family: Theme.font
							font.pixelSize: Theme.fontSize
						}

						Text {
							width: parent.width
							text: Events.about(calendarRow.modelData)
							textFormat: Text.PlainText
							color: Events.trouble[calendarRow.modelData] ? Theme.colors.error : Theme.colors.subtext
							elide: Text.ElideMiddle
							font.family: Theme.font
							font.pixelSize: Theme.fontSize - Theme.u(2)
						}
					}

					Button {
						id: calendarDrop

						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						height: Theme.u(30)
						flat: true
						icon: "close"
						tip: Tr.t("Remove it")
						onClicked: page.removeCalendar(calendarRow.modelData)
					}
				}
			}

			Item {
				width: parent.width
				height: Theme.u(40)

				Column {
					anchors.left: parent.left
					anchors.right: calendarField.left
					anchors.rightMargin: Theme.u(12)
					anchors.verticalCenter: parent.verticalCenter

					Text {
						width: parent.width
						text: Tr.t("Add a calendar")
						color: Theme.colors.text
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Text {
						width: parent.width
						text: calendarField.wrong ? Tr.t("A file by its whole path, or an address") : Tr.t("An .ics file or an iCal address, for the month")
						color: calendarField.wrong ? Theme.colors.error : Theme.colors.subtext
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize - Theme.u(2)
					}
				}

				TextField {
					id: calendarField

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					implicitWidth: Theme.u(170)
					implicitHeight: Theme.u(32)
					placeholder: "~/calendar.ics"
					onTextChanged: wrong = false
					onAccepted: {
						if (text.trim() === "")
							return;
						if (page.addCalendar(text.trim()))
							text = "";
						else
							wrong = true;
					}
				}
			}
		}
	}

	Component {
		id: workspaceSettings

		Column {
			spacing: Theme.u(10)

			Pick {
				holds: "workspaces.labels"
				text: Tr.t("On each")
				subtext: Tr.t("A name is niri's, where its config gives one")
				options: [
					{ value: "none", text: Tr.t("Nothing") },
					{ value: "number", text: Tr.t("Its number") },
					{ value: "name", text: Tr.t("Its name") }
				]
				value: Settings.workspaces.labels
				onChosen: value => Settings.set("workspaces", "labels", value)
			}

			Pick {
				holds: "workspaces.numerals"
				words: "roman numbers digits"
				visible: Settings.workspaces.labels !== "none"
				text: Tr.t("Numbers as")
				options: [
					{ value: "arabic", text: "1 2 3" },
					{ value: "roman", text: "I II III" },
					{ value: "kanji", text: [0x4e00, 0x4e8c, 0x4e09].map(point => String.fromCodePoint(point)).join(" ") },
					{ value: "circled", text: [0x2460, 0x2461, 0x2462].map(point => String.fromCodePoint(point)).join(" ") }
				]
				value: Settings.workspaces.numerals
				onChosen: value => Settings.set("workspaces", "numerals", value)
			}

			Pick {
				holds: "workspaces.shape"
				words: "pill square rounded"
				text: Tr.t("Their shape")
				options: [
					{ value: "round", text: Tr.t("Round") },
					{ value: "square", text: Tr.t("Square") }
				]
				value: Settings.workspaces.shape
				onChosen: value => Settings.set("workspaces", "shape", value)
			}

			Setting {
				holds: "workspaces.apps"
				text: Tr.t("The apps on each")
				subtext: Tr.t("Their icons: a click on one goes to its window")
				checked: Settings.workspaces.apps
				onToggled: wanted => Settings.set("workspaces", "apps", wanted)
			}

			Setting {
				holds: "workspaces.occupied"
				text: Tr.t("Those with windows stand out")
				checked: Settings.workspaces.occupied
				onToggled: wanted => Settings.set("workspaces", "occupied", wanted)
			}

			Setting {
				holds: "workspaces.empty"
				text: Tr.t("Empty ones too")
				subtext: Tr.t("Off, only those with windows and the one you're on")
				checked: Settings.workspaces.empty
				onToggled: wanted => Settings.set("workspaces", "empty", wanted)
			}

			Setting {
				holds: "workspaces.reverse"
				text: Tr.t("The wheel the other way")
				subtext: Tr.t("Up goes to the next one")
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
				holds: "battery.show"
				text: Tr.t("It shows")
				subtext: Tr.t("How low is low is on the Session page")
				options: [
					{ value: "always", text: Tr.t("Always") },
					{ value: "battery", text: Tr.t("On battery") },
					{ value: "low", text: Tr.t("When low") }
				]
				value: Settings.battery.show
				onChosen: value => Settings.set("battery", "show", value)
			}

			Pick {
				holds: "battery.label"
				text: Tr.t("Beside it")
				subtext: Tr.t("The time, where it's known")
				options: [
					{ value: "percent", text: Tr.t("Percent") },
					{ value: "time", text: Tr.t("Time left") },
					{ value: "none", text: Tr.t("Nothing") }
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
				holds: "media.show"
				text: Tr.t("It shows")
				options: [
					{ value: "player", text: Tr.t("With a player") },
					{ value: "playing", text: Tr.t("While it plays") }
				]
				value: Settings.media.show
				onChosen: value => Settings.set("media", "show", value)
			}

			Pick {
				holds: "media.label"
				text: Tr.t("On it")
				options: [
					{ value: "title", text: Tr.t("The title") },
					{ value: "both", text: Tr.t("Artist, title") },
					{ value: "none", text: Tr.t("Only the icon") }
				]
				value: Settings.media.label
				onChosen: value => Settings.set("media", "label", value)
			}

			Choice {
				holds: "media.width"
				text: Tr.t("Widest")
				subtext: Tr.t("Past that the title is cut")
				visible: Settings.media.label !== "none"
				values: [120, 160, 200, 280, 360]
				value: Settings.media.width
				unit: " px"
				onChosen: value => Settings.set("media", "width", value)
			}

			Setting {
				holds: "media.scroll"
				text: Tr.t("What's cut slides by")
				subtext: Tr.t("Under the pointer, to its end and back")
				visible: Settings.media.label !== "none"
				checked: Settings.media.scroll
				onToggled: wanted => Settings.set("media", "scroll", wanted)
			}

			Setting {
				holds: "media.menu"
				words: "exclude ignore browser"
				text: Tr.t("A right click leaves a player out")
				subtext: Tr.t("On it on the bar, and on one in its card")
				checked: Settings.media.menu
				onToggled: wanted => Settings.set("media", "menu", wanted)
			}

			Note {
				text: page.players.length > 0 ? Tr.t("Players: one turned off is left out of the bar, its card and the media keys.") : Tr.t("Players show here as they open.")
			}

			Repeater {
				model: page.players

				Setting {
					required property var modelData

					text: modelData.name
					subtext: modelData.there ? "" : Tr.t("Not open now")
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
				holds: "system.cpu"
				text: Tr.t("The processor")
				subtext: Tr.t("How busy it is")
				checked: Settings.system.cpu
				onToggled: wanted => Settings.set("system", "cpu", wanted)
			}

			Setting {
				holds: "system.memory"
				text: Tr.t("Memory")
				subtext: Tr.t("How much is in use")
				checked: Settings.system.memory
				onToggled: wanted => Settings.set("system", "memory", wanted)
			}

			Setting {
				holds: "system.temperature"
				text: Tr.t("Temperature")
				subtext: Tr.t("The processor's, where it has a sensor")
				checked: Settings.system.temperature
				onToggled: wanted => Settings.set("system", "temperature", wanted)
			}

			Setting {
				holds: "system.network"
				text: Tr.t("The network")
				subtext: Tr.t("How fast it comes in and goes out")
				checked: Settings.system.network
				onToggled: wanted => Settings.set("system", "network", wanted)
			}

			Choice {
				holds: "system.interval"
				text: Tr.t("Read every")
				values: [1, 2, 5, 10]
				value: Settings.system.interval
				onChosen: value => Settings.set("system", "interval", value)
			}

			Field {
				holds: "system.format"
				words: "template text"
				text: Tr.t("Written as")
				subtext: Tr.t("With {cpu}, {memory}, {temperature}, {down}, {up}, {swap}, {disk}; empty for the above")
				placeholder: "{cpu}% {temperature}°"
				value: Settings.system.format
				onKept: value => Settings.set("system", "format", value)
			}

			Repeater {
				model: [
					{ name: "temperature", text: Tr.t("Red from a temperature of"), values: [0, 70, 75, 80, 85, 90, 95], unit: "°" },
					{ name: "cpu", text: Tr.t("Red from the processor at"), values: [0, 50, 70, 80, 90, 95], unit: "%" },
					{ name: "memory", text: Tr.t("Red from memory at"), values: [0, 50, 70, 80, 90, 95], unit: "%" }
				]

				Choice {
					required property var modelData

					holds: "system.alerts"
					words: "warning threshold alert"
					text: modelData.text
					values: modelData.values
					value: Settings.system.alerts?.[modelData.name] ?? 0
					unit: modelData.unit
					onChosen: value => Settings.set("system", "alerts", Object.assign({}, Settings.system.alerts, { [modelData.name]: value }))
				}
			}
		}
	}

	Component {
		id: networkSettings

		Pick {
			holds: "network.label"
			text: Tr.t("Beside it")
			options: [
				{ value: "none", text: Tr.t("Nothing") },
				{ value: "name", text: Tr.t("The network") }
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
				holds: "bluetooth.show"
				text: Tr.t("It shows")
				options: [
					{ value: "connected", text: Tr.t("With a device") },
					{ value: "on", text: Tr.t("While it's on") }
				]
				value: Settings.bluetooth.show
				onChosen: value => Settings.set("bluetooth", "show", value)
			}

			Pick {
				holds: "bluetooth.label"
				text: Tr.t("Beside it")
				options: [
					{ value: "none", text: Tr.t("Nothing") },
					{ value: "name", text: Tr.t("The device") }
				]
				value: Settings.bluetooth.label
				onChosen: value => Settings.set("bluetooth", "label", value)
			}
		}
	}

	Component {
		id: updatesSettings

		Column {
			spacing: Theme.u(10)

			Choice {
				holds: "updates.every"
				words: "updates upgrade packages pacman apt dnf flatpak"
				text: Tr.t("It looks every")
				subtext: Updates.there.length > 0 ? `By ${Updates.there.join(", ")}` : "Nothing here to ask: pacman's checkupdates, apt, dnf or flatpak"
				values: [1, 3, 6, 12, 24]
				unit: "h"
				value: Settings.updates.every
				onChosen: value => Settings.set("updates", "every", value)
			}

			Field {
				holds: "updates.command"
				text: Tr.t("A click runs")
				subtext: Tr.t("A terminal with the update, say")
				placeholder: "kitty -e sudo pacman -Syu"
				value: Settings.updates.command
				onKept: value => Settings.set("updates", "command", value.trim())
			}
		}
	}

	Component {
		id: visualizerSettings

		Column {
			spacing: Theme.u(10)

			Choice {
				holds: "visualizer.bars"
				words: "cava visualizer spectrum audio"
				text: Tr.t("How many bars")
				subtext: Visualizer.found ? "" : Tr.t("It takes cava")
				values: [6, 8, 10, 12, 16, 24]
				value: Settings.visualizer.bars
				onChosen: value => Settings.set("visualizer", "bars", value)
			}

			Setting {
				holds: "visualizer.playing"
				text: Tr.t("Only while a player plays")
				subtext: Tr.t("Else it hears all there is, and is always there")
				checked: Settings.visualizer.playing
				onToggled: wanted => Settings.set("visualizer", "playing", wanted)
			}
		}
	}

	Component {
		id: locksSettings

		Pick {
			holds: "locks.show"
			text: Tr.t("It shows for")
			subtext: Tr.t("While that's on")
			options: [
				{ value: "caps", text: Tr.t("Caps Lock") },
				{ value: "both", text: Tr.t("Num Lock too") }
			]
			value: Settings.locks.show
			onChosen: value => Settings.set("locks", "show", value)
		}
	}

	Component {
		id: profileSettings

		Pick {
			holds: "profile.label"
			text: Tr.t("Beside it")
			options: [
				{ value: "none", text: Tr.t("Nothing") },
				{ value: "name", text: Tr.t("Its name") }
			]
			value: Settings.profile.label
			onChosen: value => Settings.set("profile", "label", value)
		}
	}

	Component {
		id: volumeSettings

		Column {
			spacing: Theme.u(10)

			Pick {
				holds: "audio.label"
				text: Tr.t("Beside it")
				options: [
					{ value: "none", text: Tr.t("Nothing") },
					{ value: "percent", text: Tr.t("How loud") }
				]
				value: Settings.audio.label
				onChosen: value => Settings.set("audio", "label", value)
			}

			Choice {
				holds: "audio.step"
				text: Tr.t("The wheel turns it by")
				subtext: Tr.t("Here and on the bar's own wheel")
				values: [1, 2, 5, 10]
				value: Settings.audio.step
				unit: "%"
				onChosen: value => Settings.set("audio", "step", value)
			}
		}
	}

	Component {
		id: recordingSettings

		Column {
			spacing: Theme.u(10)

			Pick {
				holds: "recording.show"
				text: Tr.t("It's on the bar")
				options: [
					{ value: "recording", text: Tr.t("While it records") },
					{ value: "always", text: Tr.t("Always, to start one") }
				]
				value: Settings.recording.show
				onChosen: value => Settings.set("recording", "show", value)
			}

			Note {
				text: Tr.t("A right click on it has what it records and with which sound; the rest is on the Display page.")
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
				text: Tr.f("Its settings are on the %1 page.", Tr.t(page.elsewhere[page.chosen]))
			}

			Button {
				id: opener

				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				height: Theme.u(30)
				text: Tr.t("Open")
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
						text: Tr.t("What it's called")
						subtext: script.refused ? Tr.t("A part goes by that name") : Tr.t("On the lanes above, and in the config")
						value: script.modelData
						onKept: value => script.refused = !page.renameScript(script.modelData, value)
					}

					Field {
						text: Tr.t("Its command")
						subtext: Tr.t("For sh")
						placeholder: "date +%A"
						value: script.own.command ?? ""
						onKept: value => page.changeScript(script.modelData, "command", value)
					}

					Choice {
						text: Tr.t("It runs every")
						subtext: Tr.t("Once, each line it goes on to print is shown in turn")
						values: [0, 1, 2, 5, 10, 30, 60, 300, 900, 3600]
						value: script.own.every ?? 0
						none: Tr.t("Once")
						onChosen: value => page.changeScript(script.modelData, "every", value)
					}

					Note {
						text: Tr.t("The first line it prints shows, and the second is what the pointer on it says; or a line of JSON with text, tooltip and class. With nothing printed the part isn't there. okaeri bar update and its name runs it again at once.")
					}

					Button {
						height: Theme.u(30)
						text: Tr.t("Remove it")
						onClicked: page.removeScript(script.modelData)
					}
				}
			}
		}
	}

	Component {
		id: spacerSettings

		Note {
			text: page.chosen.startsWith("space") ? Tr.t("Room between the parts beside it. Another comes up off the bar, for more of them.") : Tr.t("A line between the parts beside it. Another comes up off the bar, for more of them.")
		}
	}

	Component {
		id: nothingSettings

		Note {
			text: Tr.t("Nothing to set for it yet.")
		}
	}
}
