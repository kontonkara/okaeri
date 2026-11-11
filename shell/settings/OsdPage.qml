import QtQuick
import qs
import qs.ui

// Where the on-screen display comes up, for how long, and what it's for.
Flickable {
	id: page

	readonly property var kinds: [
		{ name: "volume", text: "Volume", subtext: "And muting it" },
		{ name: "mic", text: "Microphone", subtext: "Its volume, and muting it" },
		{ name: "brightness", text: "Brightness" },
		{ name: "layout", text: "Keyboard layout", subtext: "With more than one" },
		{ name: "locks", text: "Caps Lock and Num Lock" },
		{ name: "profile", text: "Power profile", subtext: "Changed with no panel open, as the next three" },
		{ name: "night", text: "Night light" },
		{ name: "awake", text: "Keep awake" },
		{ name: "dnd", text: "Do Not Disturb" },
		{ name: "keys", text: "Keyboard light", subtext: "Where the keyboard has one" }
	]

	function show(name, wanted) {
		const others = Settings.osd.hidden.filter(other => other !== name);
		Settings.set("osd", "hidden", wanted ? others : others.concat([name]));
	}

	contentHeight: column.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	Glide {
		view: page
	}

	Column {
		id: column

		width: parent.width
		spacing: Math.round(Theme.u(10))

		Card {
			width: parent.width

			Pick {
				text: "Where"
				subtext: "On the screen in focus"
				options: [
					{ value: "bottom", text: "At the bottom" },
					{ value: "middle", text: "In the middle" },
					{ value: "top", text: "At the top" }
				]
				value: Settings.osd.position
				onChosen: value => Settings.set("osd", "position", value)
			}

			Choice {
				text: "For how long"
				subtext: "From the last change"
				values: [1, 1.5, 2, 3, 5]
				value: Settings.osd.duration
				onChosen: value => Settings.set("osd", "duration", value)
			}

			Setting {
				text: "The level in numbers"
				subtext: "Beside the slider"
				checked: Settings.osd.percent
				onToggled: wanted => Settings.set("osd", "percent", wanted)
			}
		}

		Card {
			width: parent.width
			title: "What has one"

			Repeater {
				model: page.kinds

				Setting {
					required property var modelData

					text: modelData.text
					subtext: modelData.subtext ?? ""
					checked: !Settings.osd.hidden.includes(modelData.name)
					onToggled: wanted => page.show(modelData.name, wanted)
				}
			}
		}
	}
}
