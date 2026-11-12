import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The volume and the microphone, with a way to mute them and an arrow to their
// pages, the brightness when there's one, the keyboard's light too, and that of
// external monitors when Ddc has them. Where there's more than one of a kind,
// each says which it is: the output and the microphone in use, the laptop's own
// screen and the monitors by their models.
Card {
	id: levels

	// The monitors with a level, which are given a slider each.
	readonly property var monitors: Ddc.displays.filter(display => display.level >= 0)

	// A monitor by its model, which is what's written on it, and by its
	// connector too where two are the same.
	function monitorName(display) {
		const modelOf = name => Quickshell.screens.find(screen => screen.name === name)?.model ?? "";
		const model = modelOf(display.name);
		if (!model)
			return display.name;
		return monitors.filter(other => modelOf(other.name) === model).length > 1 ? `${model} · ${display.name}` : model;
	}

	width: parent.width
	padding: Theme.u(6)

	// A monitor's own buttons may have moved it since: its level is asked for
	// again at each opening. This comes with the opening, or just after it.
	Component.onCompleted: {
		if (Control.open)
			Ddc.reread();
	}

	Connections {
		target: Control

		function onOpenChanged() {
			if (Control.open)
				Ddc.reread();
		}
	}

	Column {
		width: parent.width

		Level {
			enabled: Audio.ready
			// Full at the limit.
			value: Audio.volume / Audio.limit
			full: Audio.limit
			label: {
				if (Audio.outputs.length < 2)
					return "";
				return Audio.sink ? Audio.sink.description || Audio.sink.name : "None chosen";
			}
			opens: "sound"
			onMoved: wanted => Audio.change(wanted * Audio.limit - Audio.volume)

			Button {
				anchors.centerIn: parent
				height: Theme.u(28)
				flat: true
				icon: Audio.muted ? "volumeOff" : "volume"
				ink: Audio.muted ? Theme.colors.subtext : Theme.colors.text
				onClicked: Audio.toggleMute()
			}
		}

		Level {
			visible: Brightness.available
			value: Brightness.level
			// A panel of a few steps goes a whole one at a time, or a notch would
			// round back to where it was.
			step: Math.max(0.05, 1 / Math.max(1, Brightness.maximum))
			label: levels.monitors.length > 0 ? "Built-in" : ""
			onMoved: wanted => Brightness.set(wanted)

			Icon {
				anchors.centerIn: parent
				name: "sun"
			}
		}

		Level {
			visible: KeyboardLight.available
			value: KeyboardLight.level
			// A light of a few steps goes a whole one at a time, or a notch would
			// round back to where it was.
			step: Math.max(0.05, 1 / Math.max(1, KeyboardLight.maximum))
			steps: KeyboardLight.maximum
			onMoved: wanted => KeyboardLight.set(wanted)

			Icon {
				anchors.centerIn: parent
				name: "keyboard"
			}
		}

		Repeater {
			model: levels.monitors

			Level {
				required property var modelData

				label: levels.monitorName(modelData)
				value: modelData.level / modelData.max
				step: Math.max(0.05, 1 / Math.max(1, modelData.max))
				onMoved: wanted => Ddc.change(modelData, wanted)

				Icon {
					anchors.centerIn: parent
					name: "sun"
				}
			}
		}

		Level {
			// With a microphone there, but none chosen, it's there for its arrow.
			visible: Audio.micReady || Audio.inputs.length > 0
			value: Audio.micVolume
			label: {
				if (Audio.inputs.length < 2)
					return "";
				return Audio.source ? Audio.source.description || Audio.source.name : "None chosen";
			}
			opens: "mic"
			onMoved: wanted => Audio.changeMic(wanted - Audio.micVolume)

			Button {
				anchors.centerIn: parent
				height: Theme.u(28)
				flat: true
				icon: Audio.micMuted ? "micOff" : "mic"
				ink: Audio.micMuted ? Theme.colors.subtext : Theme.colors.text
				onClicked: Audio.toggleMicMute()
			}
		}
	}
}
