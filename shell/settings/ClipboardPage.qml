import QtQuick
import qs
import qs.services
import qs.ui

// What Enter does with an entry, what goes into the history and how much there
// is of it. Pausing it is the panel's, by its button: that ends with the shell.
Column {
	spacing: Math.round(Theme.u(10))

	Card {
		width: parent.width

		Text {
			readonly property var lacking: [["cliphist", "cliphist"], ["wl-paste", "wl-clipboard"], ["wtype", "wtype, to paste,"]].filter(tool => Env.lacks(tool[0])).map(tool => tool[1])

			width: parent.width
			visible: lacking.length > 0
			wrapMode: Text.WordWrap
			text: `It needs ${lacking.join(" and ")}, which ${lacking.length > 1 ? "aren't" : "isn't"} here.`
			color: Theme.colors.error
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(1)
		}

		Setting {
			holds: "clipboard.paste"
			text: "Enter pastes"
			subtext: "Into the window in focus, and Shift+Enter copies. Off it's the other way round"
			checked: Settings.clipboard.paste
			onToggled: wanted => Settings.set("clipboard", "paste", wanted)
		}

		Choice {
			holds: "clipboard.rows"
			text: "Rows in the panel"
			subtext: "The rest can be found with the filter"
			values: [50, 100, 200, 500]
			value: Settings.clipboard.rows
			unit: " "
			onChosen: value => Settings.set("clipboard", "rows", value)
		}

		Choice {
			holds: "clipboard.keep"
			words: "size limit"
			text: "Entries in the history"
			subtext: "Past that the oldest go, but for what's pinned"
			values: [100, 250, 500, 750, 1000, 2000]
			value: Settings.clipboard.keep
			unit: " "
			onChosen: value => Settings.set("clipboard", "keep", value)
		}

		Setting {
			holds: "clipboard.images"
			text: "Keep pictures"
			subtext: "Screenshots and copied images; they take room"
			checked: Settings.clipboard.images
			onToggled: wanted => Settings.set("clipboard", "images", wanted)
		}

		Field {
			holds: "clipboard.saveTo"
			text: "Pictures saved to"
			subtext: "From an entry's own view, by a right click on it"
			placeholder: "~/Pictures"
			fieldWidth: Theme.u(200)
			value: Settings.clipboard.saveTo
			onKept: value => Settings.set("clipboard", "saveTo", value.trim())
		}
	}
}
