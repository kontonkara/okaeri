pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The systemd units that failed, the system's and then the user's, looked up
// once a minute. Each has what systemctl says of it, and `user` for the user's.
Singleton {
	id: units

	readonly property var failed: system.failed.concat(own.failed)

	function check() {
		system.running = true;
		own.running = true;
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
