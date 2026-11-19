import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// With no input for a while the session locks, and later the screens go off,
// each after a slow fade to warn of it, and the machine can be put to sleep, on
// battery or always, as Settings.idle.suspendOn says, sooner on battery, and
// suspended, hibernated or both, as Settings.idle.sleepAs says, though not while
// something plays. Apps that keep the machine
// awake hold all of it off, and so does Awake. Once the session is locked, by this or
// anything else, the screens can go off sooner, after
// Settings.idle.lockedScreenOff, as logind's LockedHint says it is.
Scope {
	id: idle

	// Seconds, 0 for never.
	// On battery each comes sooner, where Settings.idle has a time for that.
	readonly property real lockAfter: Power.draining && Settings.idle.batteryLock > 0 ? Settings.idle.batteryLock : Settings.idle.lock
	readonly property real offAfter: Power.draining && Settings.idle.batteryScreenOff > 0 ? Settings.idle.batteryScreenOff : Settings.idle.screenOff
	readonly property real sleepAfter: Power.draining && Settings.idle.batterySuspend > 0 ? Settings.idle.batterySuspend : Settings.idle.suspend
	// How it sleeps, as Settings.idle.sleepAs says, where logind says it can: else
	// it suspends.
	readonly property string sleepAs: Settings.idle.sleepAs === "hibernate" && Session.canHibernate ? "hibernate"
		: Settings.idle.sleepAs === "suspend-then-hibernate" && Session.canSuspendThenHibernate ? "suspend-then-hibernate"
		: "suspend"
	// Whether the session is locked, while that's wanted: read as logind says
	// something of the session changed, by `bus`, which a test has its own of. A
	// busctl older than `wait` is asked every few seconds instead.
	property bool locked: false
	readonly property string bus: "busctl"
	readonly property bool hearing: Settings.idle.lockedScreenOff > 0
	// logind's object of this session, and whether busctl can't wait for it.
	property string session
	property bool asksOnly: false
	// Without animations it'd be a dark screen, not a fade.
	readonly property real fade: Theme.animate ? Settings.idle.fade : 0
	readonly property bool fading: (lockSoon.isIdle && !lock.isIdle) || (offSoon.isIdle && !off.isIdle)
	// Not with something playing, if Settings.idle.playingHolds says so: when that
	// stops, it sleeps.
	readonly property bool sleeping: sleep.isIdle && (Settings.idle.suspendOn !== "battery" || Power.draining) && !(Settings.idle.playingHolds && Media.playing)

	// Whether it can hibernate, for `sleepAs`.
	Component.onCompleted: Session.check()

	onSleepingChanged: {
		if (sleeping)
			Session.run(sleepAs);
	}

	component Stage: IdleMonitor {
		id: stage

		property real after: 0
		// A new timeout counts only from the next enabling.
		property bool renewing: false

		enabled: after > 0 && !Awake.on && !GameMode.awake && !renewing
		timeout: Math.max(1, after)
		onTimeoutChanged: {
			renewing = true;
			Qt.callLater(() => stage.renewing = false);
		}
	}

	Stage {
		id: lockSoon

		after: Math.max(0, idle.lockAfter - idle.fade) * (idle.fade > 0)
	}

	Stage {
		id: lock

		after: idle.lockAfter
		onIsIdleChanged: {
			if (isIdle)
				Session.run("lock");
		}
	}

	Stage {
		id: offSoon

		after: Math.max(0, idle.offAfter - idle.fade) * (idle.fade > 0)
	}

	Stage {
		id: off

		after: idle.offAfter
		onIsIdleChanged: {
			if (isIdle)
				Env.act("screens off", () => Niri.act({ PowerOffMonitors: {} }));
		}
	}

	// Locked, the screens go off sooner, and with no fade: nobody's there.
	Stage {
		id: lockedOff

		after: idle.locked ? Settings.idle.lockedScreenOff : 0
		onIsIdleChanged: {
			if (isIdle)
				Env.act("screens off", () => Niri.act({ PowerOffMonitors: {} }));
		}
	}

	onHearingChanged: {
		if (!hearing)
			locked = false;
	}

	Process {
		running: idle.hearing && idle.session === ""
		command: [idle.bus, "--system", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "GetSession", "s", "auto"]
		stdout: StdioCollector {
			onStreamFinished: idle.session = (text.match(/^o "(.*)"/) ?? [])[1] ?? ""
		}
	}

	Process {
		id: hint

		command: [idle.bus, "--system", "get-property", "org.freedesktop.login1", idle.session, "org.freedesktop.login1.Session", "LockedHint"]
		stdout: StdioCollector {
			onStreamFinished: idle.locked = idle.hearing && /\btrue\b/.test(text)
		}
	}

	// A line for each change of the session's: whether it's LockedHint's is read
	// again. It goes with the shell, however that ends.
	Process {
		id: listening

		property double started

		running: idle.hearing && idle.session !== "" && !idle.asksOnly
		command: ["setpriv", "--pdeathsig", "TERM", idle.bus, "--system", "--json=short", "wait", "--limit-messages=4294967295", "org.freedesktop.login1", idle.session, "org.freedesktop.DBus.Properties", "PropertiesChanged"]
		stdout: SplitParser {
			onRead: line => {
				if (line.includes("LockedHint"))
					hint.running = true;
			}
		}
		onRunningChanged: {
			if (running) {
				started = Date.now();
				hint.running = true;
			}
		}
		// At once and failing: no `wait` in this busctl. Later: logind went away a
		// moment, as on an update.
		onExited: code => {
			if (!idle.hearing)
				return;
			if (code !== 0 && Date.now() - started < 2000)
				idle.asksOnly = true;
			else
				again.restart();
		}
	}

	Timer {
		id: again

		interval: 5000
		onTriggered: {
			if (listening.running)
				return;
			idle.session = "";
			listening.running = Qt.binding(() => idle.hearing && idle.session !== "" && !idle.asksOnly);
		}
	}

	Timer {
		interval: 3000
		running: idle.hearing && idle.session !== "" && idle.asksOnly
		repeat: true
		triggeredOnStart: true
		onTriggered: hint.running = true
	}

	// The screens are off or locked by then, as it's set out: no fade. The charger
	// coming out while it idles counts too.
	Stage {
		id: sleep

		after: idle.sleepAfter
	}

	Variants {
		model: Quickshell.screens

		PanelWindow {
			required property var modelData

			screen: modelData
			anchors {
				top: true
				left: true
				right: true
				bottom: true
			}
			visible: idle.fading || veil.opacity > 0
			color: "transparent"
			exclusionMode: ExclusionMode.Ignore
			mask: Region {}
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.namespace: "okaeri-fade"
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

			Rectangle {
				id: veil

				anchors.fill: parent
				color: Theme.colors.background
				opacity: 0

				states: State {
					name: "fading"
					when: idle.fading

					PropertyChanges {
						veil.opacity: 1
					}
				}

				transitions: [
					Transition {
						to: "fading"

						NumberAnimation {
							property: "opacity"
							duration: idle.fade * 1000
						}
					},
					Transition {
						from: "fading"

						NumberAnimation {
							property: "opacity"
							duration: Theme.ms(160)
						}
					}
				]
			}
		}
	}
}
