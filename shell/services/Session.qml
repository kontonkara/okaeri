pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Locking, leaving and the machine's power: logind and systemd do it, or logind
// alone where there's no systemd, logind says what this machine can do, and
// Settings.session.hidden what's left out. Locking asks the session to lock, which
// a lock screen has to listen for: Settings.session.lock is a command in place
// of that, for one that doesn't.
Singleton {
	id: session

	// systemctl where it's there, and elogind's loginctl, which takes the same words,
	// where it's not.
	readonly property var power: ["sh", "-c", 'if command -v systemctl >/dev/null 2>&1; then exec systemctl "$@"; else exec loginctl "$@"; fi', "sh"]
	readonly property var commands: ({
		lock: Settings.session.lock ? ["sh", "-c", Settings.session.lock] : ["loginctl", "lock-session"],
		suspend: power.concat(["suspend"]),
		hibernate: power.concat(["hibernate"]),
		"suspend-then-hibernate": power.concat(["suspend-then-hibernate"]),
		reboot: power.concat(["reboot"]),
		firmware: power.concat(["reboot", "--firmware-setup"]),
		poweroff: power.concat(["poweroff"])
	})
	property bool canSuspend: false
	property bool canHibernate: false
	property bool canSuspendThenHibernate: false
	property bool canFirmware: false
	// Each there is, whether this machine can do it, and whether it waits out
	// Settings.session.countdown first.
	readonly property var known: [
		{ action: "lock", text: "Lock", icon: "lock", doing: "Locking", can: true },
		{ action: "suspend", text: "Suspend", icon: "moon", doing: "Suspending", can: canSuspend },
		{ action: "hibernate", text: "Hibernate", icon: "hibernate", doing: "Hibernating", can: canHibernate, waits: true },
		{ action: "logout", text: "Log out", icon: "logout", doing: "Logging out", can: true, waits: true },
		{ action: "reboot", text: "Reboot", icon: "refresh", doing: "Rebooting", can: true, waits: true },
		{ action: "firmware", text: "Reboot to firmware", icon: "chip", doing: "Rebooting to firmware", can: canFirmware, waits: true },
		{ action: "poweroff", text: "Shut down", icon: "power", doing: "Shutting down", can: true, waits: true }
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
		laterCheck.running = true;
		firmwareCheck.running = true;
	}

	// With Settings.session.lockFirst, going to sleep locks the screen before, so
	// that it's locked as the machine wakes.
	function run(action) {
		// In a window next to the real shell it's only for a look.
		if (Env.guest) {
			console.info(`okaeri: guest: session ${action}`);
			return;
		}
		if ((action === "suspend" || action === "hibernate" || action === "suspend-then-hibernate") && Settings.session.lockFirst) {
			run("lock");
			sleepAfterLock.action = action;
			sleepAfterLock.restart();
			return;
		}
		Env.act(`session ${action}`, () => {
			if (action === "logout") {
				Niri.quit();
			} else if (action === "lock") {
				// Started by niri: a lock screen the shell started would go with it,
				// at a reload, and leave the screen open.
				Niri.spawn(commands.lock);
			} else {
				runner.action = action;
				runner.command = commands[action];
				runner.running = true;
			}
		});
	}

	// The lock screen takes a moment to come up.
	Timer {
		id: sleepAfterLock

		property string action

		interval: 1000
		onTriggered: {
			Env.act(`session ${action}`, () => {
				runner.action = action;
				runner.command = session.commands[action];
				runner.running = true;
			});
		}
	}

	// What leaves or sleeps: when that's refused, by polkit or by what's holding
	// the machine awake, it says why, instead of nothing happening.
	Process {
		id: runner

		property string action

		stderr: StdioCollector {
			id: complaint
		}
		onExited: code => {
			if (code === 0)
				return;
			const row = session.known.find(other => other.action === runner.action);
			const why = complaint.text.trim().split("\n").pop() || `It ended with ${code}`;
			Quickshell.execDetached(["notify-send", "--app-name=okaeri", "--icon=dialog-error", `${row ? row.text : runner.action} didn't happen`, why]);
		}
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
		id: laterCheck

		method: "CanSuspendThenHibernate"
		onAnswered: can => session.canSuspendThenHibernate = can
	}

	Check {
		id: firmwareCheck

		method: "CanRebootToFirmwareSetup"
		onAnswered: can => session.canFirmware = can
	}
}
