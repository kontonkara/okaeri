pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keeping the machine awake: while it's on, idling does nothing. `until` is when
// it ends by itself, 0 for never.
Singleton {
	id: awake

	property alias on: kept.on
	property alias until: kept.until
	readonly property alias label: timer.label

	function toggle() {
		set(!on, 0);
	}

	function set(wanted, end) {
		on = wanted;
		until = wanted ? end : 0;
	}

	// `notches` of the wheel on: half an hour each, and off at nothing left.
	function step(notches) {
		const end = timer.stepped(notches);
		set(end > 0, end);
	}

	Expiry {
		id: timer

		until: awake.until
		onOver: awake.set(false, 0)
	}

	IpcHandler {
		target: "awake"

		function toggle(): void {
			awake.toggle();
		}

		function forSeconds(seconds: int): void {
			awake.set(true, timer.after(seconds));
		}

		function step(notches: int): void {
			awake.step(notches);
		}

		function state(): string {
			return JSON.stringify({ on: awake.on, until: awake.until });
		}
	}

	// What a reload leaves as it was.
	PersistentProperties {
		id: kept

		property bool on: false
		property double until: 0

		reloadableId: "awake"
	}
}
