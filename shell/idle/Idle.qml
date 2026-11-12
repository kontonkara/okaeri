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
	// Whether the session is locked, looked up every few seconds while that's
	// wanted, by `lockedHint`, which a test has its own of.
	property bool locked: false
	readonly property var lockedHint: ["busctl", "get-property", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "LockedHint"]
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

		enabled: after > 0 && !Awake.on && !renewing
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

	Timer {
		interval: 3000
		running: Settings.idle.lockedScreenOff > 0
		repeat: true
		triggeredOnStart: true
		onTriggered: hint.running = true
		onRunningChanged: {
			if (!running)
				idle.locked = false;
		}
	}

	Process {
		id: hint

		command: idle.lockedHint
		stdout: StdioCollector {
			onStreamFinished: idle.locked = /\btrue\b/.test(text)
		}
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
