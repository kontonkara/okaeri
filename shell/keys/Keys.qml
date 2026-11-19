import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui

// What the keyboard's keys are bound to, from the compositor's binds, and what else
// a script may want of the shell:
//
//   quickshell ipc -p <shell> call volume up 10
Scope {
	IpcHandler {
		target: "volume"

		function up(percent: int): void {
			Audio.change(percent / 100);
		}

		function down(percent: int): void {
			Audio.change(-percent / 100);
		}

		// To `percent` at once, for a script.
		function set(percent: int): void {
			Audio.change(percent / 100 - Audio.volume);
		}

		function mute(): void {
			Audio.toggleMute();
		}

		// To the next output there is, or with "previous" the one before: speakers,
		// headphones, a screen.
		function output(which: string): void {
			Audio.turn(which === "previous" ? -1 : 1);
		}
	}

	IpcHandler {
		target: "mic"

		function up(percent: int): void {
			Audio.changeMic(percent / 100);
		}

		function down(percent: int): void {
			Audio.changeMic(-percent / 100);
		}

		// To `percent` at once, for a script.
		function set(percent: int): void {
			Audio.changeMic(percent / 100 - Audio.micVolume);
		}

		function mute(): void {
			Audio.toggleMicMute();
		}
	}

	IpcHandler {
		target: "brightness"

		// Of the screen in focus: an external one by DDC, where that's on.
		function up(percent: int): void {
			if (!Ddc.take(Niri.focusedScreen, percent / 100))
				Brightness.change(percent / 100);
		}

		function down(percent: int): void {
			if (!Ddc.take(Niri.focusedScreen, -percent / 100))
				Brightness.change(-percent / 100);
		}

		// The laptop's own panel to `percent` at once, for a script.
		function set(percent: int): void {
			Brightness.change(percent / 100 - Brightness.level);
		}
	}

	IpcHandler {
		target: "media"

		function toggle(): void {
			Media.toggle();
			Media.keyed();
		}

		function stop(): void {
			Media.stop();
			Media.keyed();
		}

		// The card of what plays, on the bar of the screen in focus.
		function card(): void {
			Panels.ask("media", Niri.focusedScreen?.name ?? "");
		}

		function previous(): void {
			Media.previous();
			Media.keyed();
		}

		function next(): void {
			Media.next();
			Media.keyed();
		}

		function forward(seconds: int): void {
			Media.seek(seconds);
		}

		function back(seconds: int): void {
			Media.seek(-seconds);
		}

		// The keys and the bar go to the next player there is.
		function cycle(): void {
			Media.cycle();
		}
	}

	// Whether the bar hides, as its page of the settings has it: a key for it to
	// go out of sight, or to stay. Without the --, `show` is a command of
	// quickshell's own.
	IpcHandler {
		target: "bar"

		function show(): void {
			Settings.set("bar", "autoHide", false);
		}

		function hide(): void {
			Settings.set("bar", "autoHide", true);
		}

		function toggle(): void {
			Settings.set("bar", "autoHide", !Settings.bar.autoHide);
		}
	}

	// The month under the clock, and the load of the machine, on the bar of the
	// screen in focus or of the first that has them.
	IpcHandler {
		target: "calendar"

		function toggle(): void {
			Panels.ask("calendar", Niri.focusedScreen?.name ?? "");
		}
	}

	// A color off the screen, by a click on it: copied as #rrggbb, and said.
	IpcHandler {
		target: "color"

		function pick(): void {
			Env.act("color pick", () => Niri.pickColor());
		}
	}

	Connections {
		target: Niri

		function onColorPicked(color) {
			Quickshell.execDetached(["wl-copy", "--", color]);
			Quickshell.execDetached(["notify-send", "--app-name=okaeri", "--icon=color-select-symbolic", color, "Copied"]);
		}
	}

	// A timer, for as long as "10m", "1h30m", "45s" or "1:30" says, a number alone
	// being minutes, and the stopwatch.
	IpcHandler {
		target: "timer"

		function start(length: string): void {
			const seconds = Timers.parse(length);
			if (seconds > 0)
				Timers.start(seconds, "");
			else
				console.info(`okaeri: no timer for "${length}": it's as 10m, 1h30m, 45s or 1:30`);
		}

		function stop(): void {
			Timers.stop();
		}

		// What's left of it, in seconds, 0 with none.
		function left(): int {
			return Timers.left;
		}
	}

	// Pomodoros: work, a break and again, as Settings.pomodoro has them, and where
	// they are, as JSON.
	IpcHandler {
		target: "pomodoro"

		function start(): void {
			Timers.startPomodoro();
		}

		function stop(): void {
			Timers.stop();
		}

		function state(): string {
			return JSON.stringify({ phase: Timers.phase, rounds: Timers.rounds, left: Timers.left });
		}
	}

	IpcHandler {
		target: "stopwatch"

		function toggle(): void {
			Timers.toggleWatch();
		}

		function reset(): void {
			Timers.resetWatch();
		}

		function seconds(): int {
			return Timers.watched;
		}
	}

	IpcHandler {
		target: "load"

		function toggle(): void {
			Panels.ask("load", Niri.focusedScreen?.name ?? "");
		}
	}

	// `okaeri notes add "buy milk"`, what's to do, as JSON, and the card of them on
	// the bar of the screen in focus.
	IpcHandler {
		target: "notes"

		function add(text: string): void {
			Notes.add(text);
		}

		function list(): string {
			return JSON.stringify(Notes.todos);
		}

		function toggle(): void {
			Panels.ask("notes", Niri.focusedScreen?.name ?? "");
		}
	}

	// The battery's card, on the bar of the screen in focus.
	IpcHandler {
		target: "battery"

		function toggle(): void {
			Panels.ask("battery", Niri.focusedScreen?.name ?? "");
		}

		// Charging stopped short of full, where UPower can, and whether it is.
		function limit(on: bool): void {
			Power.setLimit(on);
		}

		function limited(): bool {
			return Power.limited;
		}
	}

	// The keyboard's own light, where it has one.
	IpcHandler {
		target: "keylight"

		function up(percent: int): void {
			KeyboardLight.change(percent / 100);
		}

		function down(percent: int): void {
			KeyboardLight.change(-percent / 100);
		}

		// To `percent` of its light at once, the step nearest that.
		function set(percent: int): void {
			KeyboardLight.set(percent / 100);
		}
	}

	// The screen as a video, from now, or no longer: `okaeri record toggle`.
	IpcHandler {
		target: "record"

		function toggle(): void {
			Recorder.toggle();
		}

		function start(): void {
			Recorder.start();
		}

		function stop(): void {
			if (Recorder.recording)
				Recorder.stop();
		}
	}
}
