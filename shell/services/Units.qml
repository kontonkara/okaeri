pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The systemd units that failed, the system's and then the user's, looked up
// once a minute. Each has what systemctl says of it, and `user` for the user's.
// act() starts one again or takes its failure off the list, through systemd's
// bus, where a system unit has polkit ask who's asking.
Singleton {
	id: units

	readonly property var failed: system.failed.concat(own.failed)

	function check() {
		system.running = true;
		own.running = true;
	}

	// What's asked of them and not begun, and why the last of it failed: { unit,
	// text }, or null.
	property var asked: []
	property var trouble: null
	// What the journal last said of a unit, by its name, a few lines, and which
	// unit that was asked of last.
	property var told: ({})
	property string telling: ""

	// The last lines its journal has of `unit`: what it said as it failed. They
	// come into `told`; a system journal the user can't read says so.
	function explain(unit) {
		telling = unit.unit;
		reader.command = ["journalctl", ...(unit.user ? ["--user"] : []), "-u", unit.unit, "-n", "8", "-o", "cat", "--no-pager"];
		reader.running = true;
	}

	Process {
		id: reader

		stdout: StdioCollector {
			id: lines
		}
		onExited: code => {
			const said = lines.text.trim();
			units.told = Object.assign({}, units.told, { [units.telling]: said || (code === 0 ? "The journal has nothing of it" : "The journal can't be read here") });
			console.info("okaeri: units: told", said.split("\n").filter(line => line !== "").length);
		}
	}

	// `verb` is "restart" or "clear".
	function act(unit, verb) {
		Env.act(`unit ${verb}`, () => {
			asked = asked.concat([{ unit, verb }]);
			next();
		});
	}

	function next() {
		if (worker.running || asked.length === 0)
			return;
		const request = asked[0];
		asked = asked.slice(1);
		worker.unit = request.unit.unit;
		worker.command = ["busctl", ...(request.unit.user ? ["--user"] : []), "call", "org.freedesktop.systemd1", "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager"].concat(request.verb === "restart" ? ["RestartUnit", "ss", request.unit.unit, "replace"] : ["ResetFailedUnit", "s", request.unit.unit]);
		worker.running = true;
	}

	Process {
		id: worker

		property string unit

		stderr: StdioCollector {
			id: said
		}
		onExited: code => {
			units.trouble = code === 0 ? null : { unit, text: said.text.trim().split("\n").pop().replace(/^Call failed: /, "") || "It didn't take" };
			units.check();
			units.next();
		}
	}

	component Manager: Process {
		id: manager

		property bool user: false
		property var failed: []

		command: ["systemctl", ...(user ? ["--user"] : []), "--failed", "--output=json"]
		stdout: StdioCollector {
			onStreamFinished: manager.failed = JSON.parse(text || "[]").map(unit => Object.assign({}, unit, { user: manager.user }))
		}
	}

	Manager {
		id: system
	}

	Manager {
		id: own

		user: true
	}

	Timer {
		interval: 60000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: units.check()
	}

	IpcHandler {
		target: "units"

		function check(): void {
			units.check();
		}
	}
}
