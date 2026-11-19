import QtQuick
import qs
import qs.ui

// Where the on-screen display comes up, for how long, and what it's for.
Flickable {
	id: page

	readonly property var kinds: [
		{ name: "volume", text: Tr.t("Volume"), subtext: Tr.t("And muting it") },
		{ name: "mic", text: Tr.t("Microphone"), subtext: Tr.t("Its volume, and muting it") },
		{ name: "brightness", text: Tr.t("Brightness") },
		{ name: "layout", text: Tr.t("Keyboard layout"), subtext: Tr.t("With more than one") },
		{ name: "locks", text: Tr.t("Caps Lock and Num Lock") },
		{ name: "profile", text: Tr.t("Power profile"), subtext: Tr.t("Changed with no panel open, as the next three") },
		{ name: "night", text: Tr.t("Night light") },
		{ name: "awake", text: Tr.t("Keep awake") },
		{ name: "dnd", text: Tr.t("Do Not Disturb") },
		{ name: "keys", text: Tr.t("Keyboard light"), subtext: Tr.t("Where the keyboard has one") },
		{ name: "media", text: Tr.t("What plays"), subtext: Tr.t("After a key of the player's") }
	]

	// Those the files leave out, for each line's mark.
	readonly property var fileHidden: Settings.inFiles("osd", "hidden") ?? []

	function show(name, wanted) {
		const others = Settings.osd.hidden.filter(other => other !== name);
		Settings.setNames("osd", "hidden", wanted ? others : others.concat([name]));
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
				holds: "osd.position"
				words: "popup"
				text: Tr.t("Where")
				subtext: Tr.t("On the screen in focus")
				options: [
					{ value: "bottom", text: Tr.t("At the bottom") },
					{ value: "middle", text: Tr.t("In the middle") },
					{ value: "top", text: Tr.t("At the top") }
				]
				value: Settings.osd.position
				onChosen: value => Settings.set("osd", "position", value)
			}

			Choice {
				holds: "osd.duration"
				text: Tr.t("For how long")
				subtext: Tr.t("From the last change")
				values: [1, 1.5, 2, 3, 5]
				value: Settings.osd.duration
				onChosen: value => Settings.set("osd", "duration", value)
			}

			Setting {
				holds: "osd.percent"
				text: Tr.t("The level in numbers")
				subtext: Tr.t("Beside the slider")
				checked: Settings.osd.percent
				onToggled: wanted => Settings.set("osd", "percent", wanted)
			}

			Setting {
				holds: "osd.tracks"
				words: "song music"
				text: Tr.t("A track as it starts")
				subtext: Tr.t("What plays, with no key pressed")
				checked: Settings.osd.tracks
				onToggled: wanted => Settings.set("osd", "tracks", wanted)
			}
		}

		Card {
			width: parent.width
			title: Tr.t("What has one")

			Repeater {
				model: page.kinds

				Setting {
					required property var modelData

					holds: "osd.hidden"
					differs: page.fileHidden.includes(modelData.name) !== Settings.osd.hidden.includes(modelData.name)
					back: () => page.show(modelData.name, !page.fileHidden.includes(modelData.name))
					text: modelData.text
					subtext: modelData.subtext ?? ""
					checked: !Settings.osd.hidden.includes(modelData.name)
					onToggled: wanted => page.show(modelData.name, wanted)
				}
			}
		}
	}
}
