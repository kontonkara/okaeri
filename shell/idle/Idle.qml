import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// With no input for a while the session locks, and later the screens go off,
// each after a slow fade to warn of it, and the machine can be put to sleep, on
// battery or always, as Settings.idle.suspendOn says, though not while something
// plays. Apps that keep the machine
// awake hold all of it off, and so does Awake.
Scope {
	id: idle

	// Seconds, 0 for never.
	readonly property real lockAfter: Settings.idle.lock
	readonly property real offAfter: Settings.idle.screenOff
	readonly property real sleepAfter: Settings.idle.suspend
	// Without animations it'd be a dark screen, not a fade.
	readonly property real fade: Theme.animate ? Settings.idle.fade : 0
	readonly property bool fading: (lockSoon.isIdle && !lock.isIdle) || (offSoon.isIdle && !off.isIdle)
	// Not with something playing, if Settings.idle.playingHolds says so: when that
	// stops, it sleeps.
	readonly property bool sleeping: sleep.isIdle && (Settings.idle.suspendOn !== "battery" || Power.draining) && !(Settings.idle.playingHolds && Media.playing)

	onSleepingChanged: {
		if (sleeping)
			Session.run("suspend");
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
							duration: 160
						}
					}
				]
			}
		}
	}
}
