import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// What the keyboard's keys are bound to, from the compositor's binds:
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
}
