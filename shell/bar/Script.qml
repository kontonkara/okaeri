import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.ui

// A part of the user's own, the one of Settings.bar.scripts that's called `name`:
// { name, command, every }. What its command prints is on it: the first line, and
// the second is what the pointer on it says; or a line of JSON, as waybar's
// scripts print, with "text", "tooltip" and "class", which makes it red when it's
// "critical". The command runs every so many seconds, or once with `every` 0, and
// then each line it prints, for as long as it runs, is the next thing to show.
// With nothing to show the part isn't there.
Button {
	id: part

	required property string name
	readonly property var own: Settings.bar.scripts.find(other => other.name === name) ?? ({})
	readonly property string command: own.command ?? ""
	readonly property real every: own.every ?? 0
	readonly property bool stays: every <= 0
	// What makes a run another one.
	readonly property string run: `${every} ${command}`
	property string said
	property string hint
	property bool critical: false
	readonly property bool wanted: said !== ""
	// What a run has printed so far, and whether it's one that was told to stop,
	// for another to start: what it still prints isn't for showing.
	property var lines: []
	property bool stale: false

	function take(lines) {
		let text = lines[0] ?? "";
		let tip = lines[1] ?? "";
		let kind = "";
		if (text.startsWith("{")) {
			try {
				const told = JSON.parse(text);
				text = `${told.text ?? ""}`;
				tip = `${told.tooltip ?? ""}`;
				kind = [].concat(told.class ?? []).join(" ");
			} catch (error) {
				// Not JSON after all: it's what it says.
			}
		}
		// One line of it: the bar has one.
		said = text.split("\n")[0].trim();
		hint = tip.trim();
		critical = kind.split(" ").includes("critical");
	}

	// A run is in a session of its own, and all of it stops: the ends of a pipe,
	// and what a loop waits for.
	function stop() {
		if (process.running)
			Quickshell.execDetached(["kill", "--", `-${process.processId}`]);
	}

	// Another command or pace: the run there is stops first.
	function renew() {
		take([]);
		lines = [];
		if (process.running) {
			stale = true;
			stop();
		} else {
			start();
		}
	}

	function start() {
		stale = false;
		if (command !== "")
			process.running = true;
	}

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	longest: Theme.u(240)
	activeFocusOnTab: false
	text: said
	tip: hint
	ink: critical ? Theme.colors.error : Theme.colors.text

	onRunChanged: renew()
	Component.onCompleted: start()
	Component.onDestruction: stop()

	Process {
		id: process

		command: ["setsid", "sh", "-c", part.command]
		stdout: SplitParser {
			onRead: line => {
				if (part.stale)
					return;
				if (part.stays)
					part.take([line]);
				else
					part.lines.push(line);
			}
		}
		onExited: {
			if (part.stale) {
				part.start();
			} else if (!part.stays) {
				part.take(part.lines);
				part.lines = [];
			}
		}
	}

	Timer {
		interval: Math.max(1, part.every) * 1000
		running: part.command !== "" && !part.stays
		repeat: true
		onTriggered: {
			if (!part.stale)
				process.running = true;
		}
	}
}
