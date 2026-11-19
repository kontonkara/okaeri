pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// How loud the sound is across its pitches, low to high, Settings.visualizer.bars
// of them from 0 to 1, as cava hears it from PipeWire: only while a part on a bar
// counts itself in, and with Settings.visualizer.playing, while a player plays.
// By `tool`, which a test has its own of.
Singleton {
	id: visualizer

	readonly property string tool: "cava"
	property int users: 0
	property bool found: false
	readonly property bool wanted: users > 0 && found && (!Settings.visualizer.playing || Media.playing)
	property var levels: []
	readonly property string config: `[general]
bars = ${Math.max(2, Math.min(64, Settings.visualizer.bars))}
framerate = 30
[input]
method = pipewire
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
`

	onWantedChanged: {
		if (!wanted)
			levels = [];
	}

	Process {
		running: true
		command: ["sh", "-c", 'command -v "$1" >/dev/null', "sh", visualizer.tool]
		onExited: code => visualizer.found = code === 0
	}

	// Started anew as the number of bars changes: cava reads its config once.
	Process {
		running: visualizer.wanted
		command: ["setpriv", "--pdeathsig", "TERM", "sh", "-c", 'dir=${XDG_RUNTIME_DIR:-/tmp}/okaeri; mkdir -p "$dir" && printf "%s" "$1" >"$dir/cava.conf" && exec "$2" -p "$dir/cava.conf"', "sh", visualizer.config, visualizer.tool]
		stdout: SplitParser {
			onRead: line => visualizer.levels = line.split(";").filter(part => part !== "").map(part => Math.max(0, Math.min(1, Number(part) / 100)))
		}
	}
}
