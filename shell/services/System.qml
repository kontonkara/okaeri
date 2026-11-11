pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// How busy the processor is, how much memory and swap are in use, how fast the
// network goes, how full the disk under / is, and how warm the
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
	// Swap in use and the disk under / filled, in percent, -1 with none or
	// before it's known.
	property real swap: -1
	property real disk: -1
	// What comes in and goes out over the network, in bytes a second, and the
	// totals and the time of the last look, for the next to go from.
	property real down: 0
	property real up: 0
	property var lastNet: null
	// Degrees Celsius, -1 with no sensor.
	property real temperature: -1
	property string sensor: ""
	// The last of each, as many as `kept`, the newest last, for a line of them.
	readonly property int kept: 60
	property var cpus: []
	property var memories: []
	property var downs: []
	property var ups: []
	// The last /proc/stat line's busy and all, for the next to go from.
	property var last: null

	function read() {
		stat.reload();
		meminfo.reload();
		network.reload();
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

	function keep(values, value) {
		return values.concat([value]).slice(-kept);
	}

	// As many bytes as it takes, in whatever unit keeps that short.
	function rate(bytes) {
		return bytes < 1024000 ? `${Math.round(bytes / 1024)}K` : `${(bytes / 1048576).toFixed(1)}M`;
	}

	// The disk fills slowly: looked at once a minute.
	Timer {
		running: system.users > 0
		interval: 60000
		repeat: true
		triggeredOnStart: true
		onTriggered: filled.running = true
	}

	Process {
		id: filled

		command: ["df", "-P", "/"]
		stdout: StdioCollector {
			onStreamFinished: {
				const percent = (text.trim().split("\n").pop().match(/(\d+)%/) ?? [])[1];
				system.disk = percent === undefined ? -1 : Number(percent);
			}
		}
	}

	// Every interface but the loopback one, in and out, since the last look.
	FileView {
		id: network

		path: "/proc/net/dev"
		blockLoading: true
		printErrors: false
		onLoaded: {
			let received = 0;
			let sent = 0;
			text().split("\n").slice(2).forEach(line => {
				const parts = line.trim().split(/[:\s]+/);
				if (parts.length > 9 && parts[0] !== "lo") {
					received += Number(parts[1]);
					sent += Number(parts[9]);
				}
			});
			const now = Date.now();
			if (system.lastNet && now > system.lastNet.at) {
				const seconds = (now - system.lastNet.at) / 1000;
				system.down = Math.max(0, (received - system.lastNet.received) / seconds);
				system.up = Math.max(0, (sent - system.lastNet.sent) / seconds);
				system.downs = system.keep(system.downs, system.down);
				system.ups = system.keep(system.ups, system.up);
			}
			system.lastNet = { at: now, received, sent };
		}
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
			if (system.last && all > system.last.all) {
				system.cpu = Math.round(100 * (1 - (idle - system.last.idle) / (all - system.last.all)));
				system.cpus = system.keep(system.cpus, system.cpu);
			}
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
			const swapTotal = value("SwapTotal");
			system.swap = swapTotal > 0 ? Math.round(100 * (swapTotal - value("SwapFree")) / swapTotal) : -1;
			if (total > 0) {
				system.memoryTotal = total * 1024;
				system.memoryUsed = (total - available) * 1024;
				system.memory = Math.round(100 * (total - available) / total);
				system.memories = system.keep(system.memories, system.memory);
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
