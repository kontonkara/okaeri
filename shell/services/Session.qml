pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Locking, leaving and the machine's power: logind and systemd do it, logind
// says what this machine can do, and Settings.session.hidden what's left out.
Singleton {
	id: session

	readonly property var commands: ({
		lock: ["loginctl", "lock-session"],
		suspend: ["systemctl", "suspend"],
		hibernate: ["systemctl", "hibernate"],
		reboot: ["systemctl", "reboot"],
		firmware: ["systemctl", "reboot", "--firmware-setup"],
		poweroff: ["systemctl", "poweroff"]
	})
	property bool canSuspend: false
	property bool canHibernate: false
	property bool canFirmware: false
	// Each there is, and whether this machine can do it.
	readonly property var known: [
		{ action: "lock", text: "Lock", icon: "lock", doing: "Locking", can: true },
		{ action: "suspend", text: "Suspend", icon: "moon", doing: "Suspending", can: canSuspend },
		{ action: "hibernate", text: "Hibernate", icon: "hibernate", doing: "Hibernating", can: canHibernate },
		{ action: "logout", text: "Log out", icon: "logout", doing: "Logging out", can: true },
		{ action: "reboot", text: "Reboot", icon: "refresh", doing: "Rebooting", can: true },
		{ action: "firmware", text: "Reboot to firmware", icon: "chip", doing: "Rebooting to firmware", can: canFirmware },
		{ action: "poweroff", text: "Shut down", icon: "power", doing: "Shutting down", can: true }
	]
	// What can be asked for, in the menu and the launcher alike.
	readonly property var actions: known.filter(row => row.can && !Settings.session.hidden.includes(row.action))

	// One of `actions` from elsewhere: the menu counts it down.
	signal asked(var row)
	// The menu, from elsewhere.
	signal menuWanted

	// It can change, with what's holding the machine awake.
	function check() {
		suspendCheck.running = true;
		hibernateCheck.running = true;
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
		id: hibernateCheck

		method: "CanHibernate"
		onAnswered: can => session.canHibernate = can
	}

	Check {
		id: firmwareCheck

		method: "CanRebootToFirmwareSetup"
		onAnswered: can => session.canFirmware = can
	}
}
