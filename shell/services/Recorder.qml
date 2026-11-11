pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The screen as a video, by wf-recorder where it's there: the screen in focus,
// or a part of it picked with slurp, as Settings.recording.area says, with what
// plays, the microphone or no sound, to a file named by the time in
// Settings.recording.folder, or the Videos folder. Stopped, it says where the
// file is, with a way to open it.
Singleton {
	id: recorder

	readonly property var own: Settings.recording
	readonly property string tool: "wf-recorder"
	// Whether there's a wf-recorder to do it, and a slurp to pick a part with.
	property bool available: false
	property bool picks: false
	// Asked to start before that was known: it starts once it is.
	property bool known: false
	property bool waiting: false
	readonly property bool recording: process.running
	// The file it goes to, and for how many seconds so far.
	property string file
	property int elapsed: 0
	readonly property string folder: own.folder || `${Quickshell.env("HOME")}/Videos`

	// 75 as 1:15.
	function clock(seconds) {
		return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
	}

	function toggle() {
		if (recording)
			stop();
		else
			start();
	}

	function start() {
		if (!known) {
			waiting = true;
			return;
		}
		if (!available || recording || picking.running)
			return;
		if (own.area === "region" && picks)
			Env.act("record a part", () => picking.running = true);
		else
			begin("");
	}

	// `part` is what slurp says of a part of the screen, "" for the screen in
	// focus: asked which of several, wf-recorder would wait for an answer.
	function begin(part) {
		const name = `${folder}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.mp4`;
		const where = part ? ["-g", part] : ["-o", Niri.focusedScreen?.name ?? ""];
		// By name: left to pick, one of wf-recorder's two ways to hear takes the
		// microphone, and the other what plays.
		const playing = Audio.sink?.name ? `${Audio.sink.name}.monitor` : "@DEFAULT_MONITOR@";
		const sound = own.audio === "system" ? [`--audio=${playing}`] : own.audio === "mic" ? [Audio.source?.name ? `--audio=${Audio.source.name}` : "--audio"] : [];
		Env.act(`record start ${part ? "part" : "screen"} ${own.audio}`, () => {
			file = name;
			elapsed = 0;
			process.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "sh", folder, tool, "-f", name].concat(where, sound);
			process.running = true;
		});
	}

	// As Ctrl+C would: it finishes the file.
	function stop() {
		Env.act("record stop", () => process.signal(2));
	}

	Process {
		running: true
		command: ["sh", "-c", `command -v ${recorder.tool} >/dev/null && echo recorder; command -v slurp >/dev/null && echo slurp`]
		stdout: StdioCollector {
			onStreamFinished: {
				recorder.available = text.includes("recorder");
				recorder.picks = text.includes("slurp");
				recorder.known = true;
				if (recorder.waiting)
					recorder.start();
				recorder.waiting = false;
			}
		}
	}

	// A part of the screen, dragged out: nothing picked is nothing recorded.
	Process {
		id: picking

		command: ["slurp"]
		stdout: StdioCollector {
			id: picked
		}
		onExited: code => {
			if (code === 0 && picked.text.trim() !== "")
				recorder.begin(picked.text.trim());
		}
	}

	Process {
		id: process

		stderr: StdioCollector {
			id: complaints
		}
		onExited: code => {
			const failed = code !== 0 && recorder.elapsed < 1;
			notice.exec(["notify-send", "--app-name=okaeri", "--icon=video-x-generic"].concat(failed ? ["Couldn't record the screen", complaints.text.trim().split("\n").pop()] : ["--action=open=Open", "Recording saved", recorder.file]));
		}
	}

	// It waits with the notification for its button.
	Process {
		id: notice

		stdout: StdioCollector {
			onStreamFinished: {
				if (text.trim() === "open")
					Niri.spawn(["xdg-open", recorder.file]);
			}
		}
	}

	Timer {
		interval: 1000
		running: recorder.recording
		repeat: true
		onTriggered: recorder.elapsed += 1
	}
}
