import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.ui

// A tile of the user's own, the one of Settings.control.custom that's called
// `name`: { name, command, check, icon }. A click runs its command, which has
// OKAERI_ON as 1 or 0 for how the tile stands. With `check`, a command that ends
// well while the thing is on, it's a switch, and looks again every few seconds
// and after each click; without, it's a button.
Tile {
	id: tile

	readonly property var own: Settings.control.custom.find(other => other.name === name) ?? ({})
	readonly property string check: own.check ?? ""
	property bool on: false

	function run() {
		Env.act("tile run", () => {
			runner.command = ["sh", "-c", own.command ?? ""];
			runner.environment = { OKAERI_ON: on ? "1" : "0" };
			runner.running = true;
		});
	}

	function look() {
		if (check !== "")
			checker.running = true;
	}

	icon: own.icon in Theme.icons ? own.icon : "play"
	title: name
	summary: check === "" ? "" : on ? "On" : "Off"
	checked: check !== "" && on
	switches: check !== ""
	onToggled: run()
	onClicked: run()
	onCheckChanged: look()
	Component.onCompleted: look()

	Process {
		id: runner

		onExited: tile.look()
	}

	Process {
		id: checker

		command: ["sh", "-c", tile.check]
		onExited: code => tile.on = code === 0
	}

	// A tile is there only while the panel is.
	Timer {
		interval: 3000
		running: tile.check !== ""
		repeat: true
		onTriggered: tile.look()
	}
}
