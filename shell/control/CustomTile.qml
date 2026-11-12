import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.ui

// A tile of the user's own, the one of Settings.control.custom that's called
// `name`: { name, command, check, icon }. A click runs its command, which has
// OKAERI_ON as 1 or 0 for how the tile stands. With `check`, a command that ends
// well while the thing is on, it's a switch, and looks again every few seconds
// and after each click, with the first line the check prints, if it prints one,
// under its name; without, it's a button. niri starts the command, as it does an
// app: a tile goes with the panel, and what it started would go too.
Tile {
	id: tile

	readonly property var own: Settings.control.custom.find(other => other.name === name) ?? ({})
	readonly property string check: own.check ?? ""
	property bool on: false
	// What the check last said of it.
	property string said: ""

	function run() {
		Env.act("tile run", () => {
			Niri.spawn(["env", `OKAERI_ON=${on ? 1 : 0}`, "sh", "-c", own.command ?? ""]);
			soon.restart();
		});
	}

	function look() {
		if (check !== "")
			checker.running = true;
	}

	icon: own.icon in Theme.icons ? own.icon : "play"
	title: name
	summary: check === "" ? "" : said || (on ? "On" : "Off")
	checked: check !== "" && on
	switches: check !== ""
	onToggled: run()
	onClicked: run()
	onCheckChanged: look()
	Component.onCompleted: look()

	// How it stands once the command has had a moment, and the look every few
	// seconds has the rest.
	Timer {
		id: soon

		interval: 600
		onTriggered: tile.look()
	}

	Process {
		id: checker

		command: ["sh", "-c", tile.check]
		stdout: StdioCollector {
			id: told
		}
		onExited: code => {
			tile.on = code === 0;
			tile.said = told.text.split("\n")[0].trim();
		}
	}

	// A tile is there only while the panel is.
	Timer {
		interval: 3000
		running: tile.check !== ""
		repeat: true
		onTriggered: tile.look()
	}
}
