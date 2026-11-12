pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The brightness of external monitors, over DDC/CI by ddcutil, while
// Settings.display.ddc says so. Only screens that are connected are asked, and
// only on a GPU that's awake: asking one that sleeps would wake it. Each in
// `displays` is { name, bus, level, max }; a change goes out once the slider
// rests. take() is a step of the brightness keys or of the wheel, for the
// screen they're on, and reread() asks for the levels again.
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

	// The levels again, of what's already found: a monitor's own buttons may
	// have moved them. The connectors are looked at again first, as that's what
	// keeps a GPU that went to sleep since then from being asked: it's sysfs, and
	// quick. Those still there keep their levels meanwhile.
	function reread() {
		if (on && available && displays.length > 0 && !finder.running && !asking.running)
			finder.running = true;
	}

	function change(display, level) {
		const value = Math.round(Math.max(0, Math.min(1, level)) * display.max);
		displays = displays.map(other => other.bus === display.bus ? Object.assign({}, other, { level: value }) : other);
		wanted = Object.assign({}, wanted, { [display.bus]: value });
		resting.restart();
	}

	// take() moved one of them to `level`, 0 to 1.
	signal stepped(real level)

	// `by` more or less on `screen`, if that's one of these: whether it was. On a
	// machine with no backlight of its own the first of them takes it for any.
	function take(screen, by) {
		const known = displays.filter(display => display.level >= 0);
		const display = known.find(other => other.name === screen?.name) ?? (Brightness.available ? null : known[0]);
		if (!display)
			return false;
		const level = Math.max(0, Math.min(1, display.level / display.max + by));
		change(display, level);
		stepped(level);
		return true;
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
				const known = ddc.displays;
				ddc.displays = text.trim().split("\n").filter(line => line !== "").map(line => {
					const [name, bus] = line.split(" ");
					const before = known.find(display => display.bus === bus);
					return before ? Object.assign({}, before, { name }) : { name, bus, level: -1, max: 100 };
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
				// One about to be changed keeps what it's to be.
				if (found && !(ddc.displays[index]?.bus in ddc.wanted))
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
