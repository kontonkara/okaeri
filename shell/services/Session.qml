pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Locking, leaving and the machine's power: logind and systemd do it, and logind
// says what this machine can do.
Singleton {
	id: session

	readonly property var commands: ({
		lock: ["loginctl", "lock-session"],
		suspend: ["systemctl", "suspend"],
		reboot: ["systemctl", "reboot"],
		firmware: ["systemctl", "reboot", "--firmware-setup"],
		poweroff: ["systemctl", "poweroff"]
	})
	property bool canSuspend: false
	property bool canFirmware: false
	// What can be asked for, in the menu and the launcher alike.
	readonly property var actions: [
		{ action: "lock", text: "Lock", icon: "lock", doing: "Locking" },
		{ action: "suspend", text: "Suspend", icon: "moon", doing: "Suspending", shows: canSuspend },
		{ action: "logout", text: "Log out", icon: "logout", doing: "Logging out" },
		{ action: "reboot", text: "Reboot", icon: "refresh", doing: "Rebooting" },
		{ action: "firmware", text: "Reboot to firmware", icon: "chip", doing: "Rebooting to firmware", shows: canFirmware },
		{ action: "poweroff", text: "Shut down", icon: "power", doing: "Shutting down" }
	].filter(row => row.shows !== false)

	// One of `actions` from elsewhere: the menu counts it down.
	signal asked(var row)

	// It can change, with what's holding the machine awake.
	function check() {
		suspendCheck.running = true;
		firmwareCheck.running = true;
	}

	function run(action) {
		// In a window next to the real shell it's only for a look.
		if (Env.guest) {
			console.info(`okaeri: guest: session ${action}`);
			return;
		}
		Env.act(`session ${action}`, () => {
			if (action === "logout")
				Niri.quit();
			else
				Quickshell.execDetached(commands[action]);
		});
	}

	component Check: Process {
		property string method
		signal answered(bool can)

		command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", method]

		stdout: StdioCollector {
			onStreamFinished: answered(/"(yes|challenge)"/.test(text))
		}
	}

	Check {
		id: suspendCheck

		method: "CanSuspend"
		onAnswered: can => session.canSuspend = can
	}

	Check {
		id: firmwareCheck

		method: "CanRebootToFirmwareSetup"
		onAnswered: can => session.canFirmware = can
	}
}
