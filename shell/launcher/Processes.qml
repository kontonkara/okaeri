pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// One's own processes, the busiest first, by top's second look, its first being
// the average since each started: looked at every two seconds while `watched`,
// as the launcher's /ps is open. One asked to end is `armed` for a few seconds:
// asked again, it ends, by TERM, or by KILL with `hard`.
Singleton {
	id: processes

	property bool watched: false
	// { pid, name, command, cpu, memory }, memory in MiB, the name the last of
	// what started it, without what Nix's wrappers make of it.
	property var list: []
	property int armed: 0
	property bool armedHard: false

	function ask(pid, hard) {
		if (armed === pid && armedHard === !!hard) {
			armed = 0;
			disarm.stop();
			Env.act(`process ${hard ? "kill" : "end"}`, () => Quickshell.execDetached(["kill", hard ? "-KILL" : "-TERM", String(pid)]));
			again.restart();
			return;
		}
		armed = pid;
		armedHard = !!hard;
		disarm.restart();
	}

	function memory(mib) {
		return mib >= 1024 ? `${(mib / 1024).toFixed(1)} GB` : `${Math.round(mib)} MB`;
	}

	Timer {
		id: disarm

		interval: 4000
		onTriggered: processes.armed = 0
	}

	Timer {
		interval: 2000
		repeat: true
		running: processes.watched
		triggeredOnStart: true
		onTriggered: looking.running = true
	}

	// A look soon after one ended, for it to be gone.
	Timer {
		id: again

		interval: 300
		onTriggered: looking.running = true
	}

	Process {
		id: looking

		command: ["sh", "-c", 'top -b -c -n 2 -d 0.5 -e m -w 512 -o %CPU -u "$(id -un)" 2>/dev/null | awk -f "$1"', "sh", Quickshell.shellPath("launcher/processes.awk")]
		stdout: StdioCollector {
			onStreamFinished: {
				processes.list = text.split("\n").filter(line => line.includes("\t")).map(line => {
					const [pid, cpu, memory, command] = line.split("\t");
					const name = command.split(" ")[0].replace(/^.*\//, "").replace(/^\./, "").replace(/-wrapped$/, "");
					return { pid: Number(pid), cpu: Number(cpu) || 0, memory: Number(memory) || 0, name, command };
				});
			}
		}
	}
}
