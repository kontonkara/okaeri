import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

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

		function mute(): void {
			Audio.toggleMicMute();
		}
	}

	IpcHandler {
		target: "brightness"

		function up(percent: int): void {
			Brightness.change(percent / 100);
		}

		function down(percent: int): void {
			Brightness.change(-percent / 100);
		}
	}

	IpcHandler {
		target: "media"

		function toggle(): void {
			Media.toggle();
		}

		function stop(): void {
			Media.stop();
		}

		function previous(): void {
			Media.previous();
		}

		function next(): void {
			Media.next();
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

	// The keyboard's own light, where it has one.
	IpcHandler {
		target: "keylight"

		function up(percent: int): void {
			KeyboardLight.change(percent / 100);
		}

		function down(percent: int): void {
			KeyboardLight.change(-percent / 100);
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
