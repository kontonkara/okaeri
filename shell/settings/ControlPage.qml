import QtQuick
import qs
import qs.ui

// Which tiles the control center has: what doesn't apply here doesn't show
// either way.
Column {
	id: page

	readonly property var sections: [
		{ name: "wifi", text: "Wi-Fi", subtext: "And its networks behind the arrow" },
		{ name: "bluetooth", text: "Bluetooth", subtext: "And its devices behind the arrow" },
		{ name: "night", text: "Night light" },
		{ name: "awake", text: "Keep awake" },
		{ name: "power", text: "Power profile", subtext: "A click goes to the next one" }
	]

	function show(name, wanted) {
		const others = Settings.control.hidden.filter(other => other !== name);
		Settings.set("control", "hidden", wanted ? others : others.concat([name]));
	}

	Card {
		width: parent.width
		title: "Tiles"

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
