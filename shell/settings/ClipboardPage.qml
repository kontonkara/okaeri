import QtQuick
import qs
import qs.ui

// What Enter does with an entry, and how much there is of the history.
Column {
	spacing: Math.round(Theme.u(10))

	Card {
		width: parent.width

		Setting {
			text: "Enter pastes"
			subtext: "Into the window in focus, and Shift+Enter copies. Off it's the other way round"
			checked: Settings.clipboard.paste
			onToggled: wanted => Settings.set("clipboard", "paste", wanted)
		}

		Choice {
			text: "Rows in the panel"
			subtext: "The rest can be found with the filter"
			values: [50, 100, 200, 500]
			value: Settings.clipboard.rows
			unit: " "
			onChosen: value => Settings.set("clipboard", "rows", value)
		}

		Choice {
			text: "Entries in the history"
			subtext: "Past that the oldest go, but for what's pinned"
			values: [100, 250, 500, 750, 1000, 2000]
			value: Settings.clipboard.keep
			unit: " "
			onChosen: value => Settings.set("clipboard", "keep", value)
		}
	}
}
