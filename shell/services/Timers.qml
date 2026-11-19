pragma Singleton

import QtQuick
import Quickshell
import qs

// A timer that counts down to a notification and a sound, and a stopwatch: one
// of each, for the clock on the bar, its card and the launcher. The timer can go
// by pomodoros too: work, a break, work again, and a longer break after
// Settings.pomodoro.rounds of work, each going on to the next by itself. They
// end with the shell.
Singleton {
	id: timers

	// When the timer is up, in milliseconds, 0 with none, and what it's for.
	property double until: 0
	property string label
	// When the stopwatch started, 0 while it stands, and what it had by then.
	property double since: 0
	property double banked: 0
	property double now: Date.now()
	readonly property bool counting: until > 0
	readonly property bool watching: since > 0
	// Seconds: what's left of the timer, and what the stopwatch has.
	readonly property int left: counting ? Math.max(0, Math.ceil((until - now) / 1000)) : 0
	readonly property int watched: Math.floor((banked + (watching ? Math.max(0, now - since) : 0)) / 1000)
	// Of pomodoros: "work", "break" or "long", "" for a timer that's only that, and
	// how many works were done.
	property string phase
	property int rounds: 0

	// How long `text` asks for, in seconds, 0 for what isn't a time: "90", minutes;
	// "10m", "1h30m", "45s", "1:30" as minutes and seconds.
	function parse(text) {
		const wanted = `${text}`.trim().toLowerCase();
		if (/^\d+(\.\d+)?$/.test(wanted))
			return Math.round(Number(wanted) * 60);
		const clock = wanted.match(/^(\d+):(\d{1,2})(?::(\d{1,2}))?$/);
		if (clock)
			return clock[3] !== undefined ? Number(clock[1]) * 3600 + Number(clock[2]) * 60 + Number(clock[3]) : Number(clock[1]) * 60 + Number(clock[2]);
		const parts = wanted.match(/^(?:(\d+(?:\.\d+)?)h)?(?:(\d+(?:\.\d+)?)m(?:in)?)?(?:(\d+)s)?$/);
		if (!parts || wanted === "")
			return 0;
		return Math.round(Number(parts[1] ?? 0) * 3600 + Number(parts[2] ?? 0) * 60 + Number(parts[3] ?? 0));
	}

	// 9:05, or 1:02:05.
	function clock(seconds) {
		const whole = Math.max(0, Math.floor(seconds));
		const hours = Math.floor(whole / 3600);
		const minutes = Math.floor(whole / 60) % 60;
		const rest = String(whole % 60).padStart(2, "0");
		return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}:${rest}` : `${minutes}:${rest}`;
	}

	// "10 min", "1 h 30 min", "45 s".
	function span(seconds) {
		const hours = Math.floor(seconds / 3600);
		const minutes = Math.floor(seconds / 60) % 60;
		const rest = seconds % 60;
		return [hours ? Tr.f("%1 h", hours) : "", minutes ? Tr.f("%1 min", minutes) : "", rest ? Tr.f("%1 s", rest) : ""].filter(part => part !== "").join(" ");
	}

	function start(seconds, what) {
		if (seconds <= 0)
			return;
		now = Date.now();
		label = what ?? "";
		until = now + seconds * 1000;
		// For tests: that it runs, and never what for.
		console.info("okaeri: timer: started", seconds);
	}

	function stop() {
		until = 0;
		label = "";
		phase = "";
		rounds = 0;
	}

	// Pomodoros, from work.
	function startPomodoro() {
		stop();
		nextPhase("work");
	}

	function nextPhase(next) {
		const own = Settings.pomodoro;
		const minutes = next === "work" ? own.work : next === "long" ? own.long : own.pause;
		start(Math.max(1, Math.round(minutes * 60)), next === "work" ? "Work" : next === "long" ? "A long break" : "A break");
		phase = next;
	}

	function toggleWatch() {
		now = Date.now();
		if (watching) {
			banked += now - since;
			since = 0;
		} else {
			since = now;
		}
	}

	function resetWatch() {
		since = 0;
		banked = 0;
	}

	function done() {
		const what = label;
		if (phase) {
			const worked = phase === "work";
			const done = rounds + (worked ? 1 : 0);
			const next = !worked ? "work" : done % Math.max(1, Settings.pomodoro.rounds) === 0 ? "long" : "break";
			nextPhase(next);
			rounds = done;
			console.info("okaeri: pomodoro:", next);
			Sounds.play("alarm-clock-elapsed");
			Env.act("pomodoro next", () => Quickshell.execDetached(["notify-send", "--app-name=okaeri", "--icon=alarm-symbolic", worked ? Tr.t("Work's done") : Tr.t("Back to work"), worked ? Tr.f(next === "long" ? "A long break, %1" : "A break, %1", timers.span(timers.left)) : Tr.f("%1 of it", timers.span(timers.left))]));
			return;
		}
		stop();
		console.info("okaeri: timer: up");
		Sounds.play("alarm-clock-elapsed");
		Env.act("timer up", () => Quickshell.execDetached(["notify-send", "--app-name=okaeri", "--icon=alarm-symbolic", "--urgency=critical", Tr.t("Time's up"), what]));
	}

	Timer {
		interval: 250
		running: timers.counting || timers.watching
		repeat: true
		onTriggered: {
			timers.now = Date.now();
			if (timers.counting && timers.now >= timers.until)
				timers.done();
		}
	}
}
