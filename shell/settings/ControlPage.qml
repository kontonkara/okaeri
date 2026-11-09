import QtQuick
import qs
import qs.ui

// What's in the control center: what doesn't apply here doesn't show either way.
Column {
	id: page

	readonly property var sections: [
		{ name: "output", text: "Output", subtext: "With more than one place for the sound to go" },
		{ name: "input", text: "Input", subtext: "With more than one microphone, or none chosen" },
		{ name: "playback", text: "Playback", subtext: "While something plays" },
		{ name: "wifi", text: "Wi-Fi" },
		{ name: "bluetooth", text: "Bluetooth" },
		{ name: "power", text: "Power profile and the battery" },
		{ name: "night", text: "Night light" },
		{ name: "awake", text: "Keep awake" }
	]

	function show(name, wanted) {
		const others = Settings.control.hidden.filter(other => other !== name);
		Settings.set("control", "hidden", wanted ? others : others.concat([name]));
	}

	Card {
		width: parent.width
		title: "In the control center"

		Repeater {
			model: page.sections

			Setting {
				required property var modelData

				text: modelData.text
				subtext: modelData.subtext ?? ""
				checked: !Settings.control.hidden.includes(modelData.name)
				onToggled: wanted => page.show(modelData.name, wanted)
			}
		}
	}
}
