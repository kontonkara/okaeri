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

	IpcHandler {
		target: "load"

		function toggle(): void {
			Panels.ask("load", Niri.focusedScreen?.name ?? "");
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
