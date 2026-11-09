pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// How busy the processor is, how much memory is in use, and how warm the
// processor is, every Settings.system.interval seconds while something `uses`
// it: from /proc, and from the processor's own sensor, the first of k10temp,
// zenpower, coretemp and cpu_thermal there is. A GPU's isn't read, as that could
// wake one that sleeps.
Singleton {
	id: system

	// What shows it: it reads only while that's more than none.
	property int users: 0
	// Percent, -1 before it's known.
	property real cpu: -1
	property real memory: -1
	property real memoryUsed: 0
	property real memoryTotal: 0
	// Degrees Celsius, -1 with no sensor.
	property real temperature: -1
	property string sensor: ""
	// The last /proc/stat line's busy and all, for the next to go from.
	property var last: null

	function read() {
		stat.reload();
		meminfo.reload();
		if (sensorFile.path !== "")
			sensorFile.reload();
	}

	Timer {
		running: system.users > 0
		interval: Math.max(1, Settings.system.interval) * 1000
		repeat: true
		triggeredOnStart: true
		onTriggered: system.read()
	}

	FileView {
		id: stat

		path: "/proc/stat"
		blockLoading: true
		printErrors: false
		onLoaded: {
			const fields = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
			const idle = fields[3] + (fields[4] || 0);
			const all = fields.reduce((sum, field) => sum + field, 0);
			if (system.last && all > system.last.all)
				system.cpu = Math.round(100 * (1 - (idle - system.last.idle) / (all - system.last.all)));
			system.last = { idle, all };
		}
	}

	FileView {
		id: meminfo

		path: "/proc/meminfo"
		blockLoading: true
		printErrors: false
		onLoaded: {
			const value = name => Number((text().match(new RegExp(`^${name}:\\s+(\\d+)`, "m")) ?? [])[1] ?? 0);
			const total = value("MemTotal");
			const available = value("MemAvailable");
			if (total > 0) {
				system.memoryTotal = total * 1024;
				system.memoryUsed = (total - available) * 1024;
				system.memory = Math.round(100 * (total - available) / total);
			}
		}
	}

	FileView {
		id: sensorFile

		path: ""
		blockLoading: true
		printErrors: false
		onLoaded: system.temperature = Math.round(Number(text()) / 1000)
	}

	// Which hwmon is the processor's: its name, and the input of its die.
	Process {
		running: true
		command: ["sh", "-c", 'for dir in /sys/class/hwmon/hwmon*; do echo "$dir $(cat "$dir/name" 2>/dev/null)"; done']

		stdout: StdioCollector {
			onStreamFinished: {
				const found = text.trim().split("\n").map(line => line.split(" ")).filter(parts => parts.length > 1);
				for (const name of ["k10temp", "zenpower", "coretemp", "cpu_thermal"]) {
					const match = found.find(parts => parts[1] === name);
					if (match) {
						system.sensor = name;
						sensorFile.path = `${match[0]}/temp1_input`;
						return;
					}
				}
			}
		}
	}
}
