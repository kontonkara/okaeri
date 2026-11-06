import QtQuick
import qs
import qs.ui

// When the session locks and the screens go off by themselves, and the time left
// to change your mind in the session menu.
Column {
	id: page

	readonly property var waits: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600]

	spacing: Math.round(Theme.u(10))

	Card {
		width: parent.width
		title: "With nothing going on"

		Choice {
			text: "Lock the session"
			values: page.waits
			value: Settings.idle.lock
			onChosen: value => Settings.set("idle", "lock", value)
		}

		Choice {
			text: "Turn the screens off"
			values: page.waits
			value: Settings.idle.screenOff
			onChosen: value => Settings.set("idle", "screenOff", value)
		}
	}

	Card {
		width: parent.width
		title: "Session menu"

		Choice {
			text: "Wait before going ahead"
			subtext: "Time to cancel a shutdown or a logout"
			values: [0, 3, 5, 10, 15, 30]
			value: Settings.session.countdown
			none: "Don't"
			onChosen: value => Settings.set("session", "countdown", value)
		}
	}
}
