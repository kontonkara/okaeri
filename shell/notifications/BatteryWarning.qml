import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Says it when the battery runs low, and again, to stay on screen, when next to
// nothing is left. It goes by how things stand, so a start on a low battery says
// it too, and the charger takes it back.
Scope {
	id: warning

	// Past this much it's the last call.
	readonly property int last: 5
	// 0 all's well, 1 low, 2 the last call.
	readonly property int level: !Power.low ? 0 : Power.charge <= last ? 2 : 1
	// What was said since the charger was last in, and the id it has on screen.
	property int said: 0
	property int shown: 0
	// UPower comes in a piece at a time: until then it can say anything.
	property bool ready: false

	function update() {
		if (!ready || Env.guest)
			return;
		if (!Power.draining) {
			said = 0;
			NotificationStore.withdraw(shown);
			shown = 0;
		} else if (level > said) {
			said = level;
			say();
		}
	}

	function say() {
		const seconds = Power.battery?.timeToEmpty ?? 0;
		const left = seconds > 0 ? `${Power.charge}%, ${Power.span(seconds)} left` : `${Power.charge}% left`;
		sender.exec(["notify-send", "--print-id", `--replace-id=${shown}`, "--app-name=okaeri", "--icon=battery-caution",
			`--urgency=${level > 1 ? "critical" : "normal"}`, level > 1 ? "Battery nearly empty" : "Battery low", left]);
	}

	onLevelChanged: update()

	Connections {
		target: Power

		function onDrainingChanged() {
			warning.update();
			if (warning.ready && Settings.sounds.power)
				Sounds.play(Power.draining ? "power-unplug" : "power-plug");
		}
	}

	Timer {
		running: true
		interval: 2000
		onTriggered: {
			warning.ready = true;
			warning.update();
		}
	}

	Process {
		id: sender

		stdout: StdioCollector {
			onStreamFinished: warning.shown = parseInt(text) || 0
		}
	}
}
