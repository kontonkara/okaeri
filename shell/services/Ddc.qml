pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The brightness of external monitors, over DDC/CI by ddcutil, while
// Settings.display.ddc says so. Only screens that are connected are asked, and
// only on a GPU that's awake: asking one that sleeps would wake it. Each in
// `displays` is { name, bus, level, max }; a change goes out once the slider
// rests.
Singleton {
	id: ddc

	readonly property bool on: Settings.display.ddc
	// Where to look and what to ask: a test puts its own.
	readonly property string drm: "/sys/class/drm"
	readonly property string tool: "ddcutil"
	property bool available: false
	property var displays: []
	// What's waiting to go out, by bus.
	property var wanted: ({})

	function find() {
		if (on && available)
			finder.running = true;
		else
			displays = [];
	}

	function change(display, level) {
		const value = Math.round(Math.max(0, Math.min(1, level)) * display.max);
		displays = displays.map(other => other.bus === display.bus ? Object.assign({}, other, { level: value }) : other);
		wanted = Object.assign({}, wanted, { [display.bus]: value });
		resting.restart();
	}

	onOnChanged: find()
	onAvailableChanged: find()

	Process {
		running: true
		command: ["sh", "-c", `command -v ${ddc.tool}`]
		onExited: code => ddc.available = code === 0
	}

	// The connectors that are connected, with a DDC bus, on a GPU that isn't
	// suspended, and not the laptop's own panel.
	Process {
		id: finder

		command: ["sh", "-c", 'for status in "$1"/card*-*/status; do dir=${status%/status}; name=${dir##*/}; [ "$(cat "$status")" = connected ] || continue; case $name in *eDP*|*LVDS*|*DSI*) continue ;; esac; [ "$(cat "$1/${name%%-*}/device/power/runtime_status" 2>/dev/null)" = suspended ] && continue; bus=$(readlink "$dir/ddc" 2>/dev/null) || continue; echo "${name#*-} ${bus##*-}"; done', "sh", ddc.drm]

		stdout: StdioCollector {
			onStreamFinished: {
				ddc.displays = text.trim().split("\n").filter(line => line !== "").map(line => {
					const [name, bus] = line.split(" ");
					return { name, bus, level: -1, max: 100 };
				});
				asking.next(0);
			}
		}
	}

	// Each display's level, one after another: the bus is slow.
	Process {
		id: asking

		property int index: 0

		function next(index) {
			if (index >= ddc.displays.length)
				return;
			asking.index = index;
			command = [ddc.tool, "--bus", ddc.displays[index].bus, "--brief", "getvcp", "10"];
			running = true;
		}

		stdout: StdioCollector {
			onStreamFinished: {
				// "VCP 10 C 50 100": what it is, and how high it goes.
				const found = text.match(/VCP 10 C (\d+) (\d+)/);
				const index = asking.index;
				if (found)
					ddc.displays = ddc.displays.map((display, at) => at === index ? Object.assign({}, display, { level: Number(found[1]), max: Number(found[2]) || 100 }) : display);
				asking.next(index + 1);
			}
		}
	}

	Timer {
		id: resting

		interval: 300
		onTriggered: {
			for (const bus of Object.keys(ddc.wanted)) {
				const value = ddc.wanted[bus];
				const display = ddc.displays.find(other => other.bus === bus);
				Env.act(`ddc ${display?.name ?? bus} ${value}`, () => Quickshell.execDetached([ddc.tool, "--bus", bus, "--noverify", "setvcp", "10", String(value)]));
			}
			ddc.wanted = {};
		}
	}

	// A screen that comes or goes.
	Connections {
		target: Quickshell

		function onScreensChanged() {
			ddc.find();
		}
	}
}
