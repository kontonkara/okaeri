pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// What's typed in the launcher, worked out by qalc, with its units and
// currencies. `result` is "" for what's no sum, and `expression` what it's of.
Singleton {
	id: calculator

	// What's to be worked out, and what qalc was last given.
	property string wanted: ""
	property string asked: ""
	property string expression: ""
	property string result: ""

	// With /calc in front anything is a sum. Else it starts as one and has
	// something to work out: 7zip and 2048 are apps' names, and qalc takes `kitty`
	// for a product of units.
	function parse(text) {
		const typed = text.trim();
		if (/^\/calc\s/i.test(typed))
			return typed.slice(5).trim();
		const starts = /^[-+(√.]*(\d|(pi|tau)\b|[a-z]+\()/i.test(typed);
		const works = /[-+*\/^%:!()×÷√]|\s(to|in)\s/i.test(typed);
		return starts && works ? typed : "";
	}

	function ask(text) {
		wanted = parse(text);
		if (!wanted) {
			expression = "";
			result = "";
		} else if (!worker.running) {
			run();
		}
	}

	function run() {
		asked = wanted;
		// The space: what starts with a - isn't an option of qalc's then.
		worker.command = ["qalc", "-t", ` ${asked}`];
		worker.running = true;
		limit.restart();
	}

	function copy() {
		const value = result;
		Env.act(`copy ${value}`, () => Quickshell.execDetached(["wl-copy", "--", value]));
	}

	Process {
		id: worker

		onRunningChanged: {
			if (running)
				return;
			limit.stop();
			if (calculator.wanted && calculator.wanted !== calculator.asked)
				calculator.run();
		}

		stdout: StdioCollector {
			onStreamFinished: {
				if (calculator.asked !== calculator.wanted)
					return;
				// Its own minus wouldn't paste as a number.
				const answer = text.split("\n")[0].trim().replace(/−/g, "-");
				calculator.expression = calculator.asked;
				calculator.result = answer !== calculator.asked ? answer : "";
			}
		}
	}

	// qalc only reads the rates it has: it fetches them when told.
	Process {
		id: rates

		command: ["qalc", "-e", "-t", "1"]
	}

	Timer {
		interval: 6 * 60 * 60 * 1000
		repeat: true
		running: true
		triggeredOnStart: true
		onTriggered: Env.act("exchange rates", () => rates.running = true)
	}

	// A factorial of a billion would go on for good, with the rest waiting for it.
	Timer {
		id: limit

		interval: 1000
		onTriggered: worker.signal(9)
	}
}
