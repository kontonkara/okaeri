import QtQuick
import qs
import qs.ui

// How loud the shell's sounds are, and what has one.
Column {
	spacing: Math.round(Theme.u(10))

	Card {
		width: parent.width

		Choice {
			text: "Volume of the sounds"
			subtext: "They go through the sound theme, freedesktop's"
			values: [0, 10, 15, 20, 25, 30, 40, 50, 75, 100]
			value: Settings.sounds.volume
			none: "Off"
			unit: "%"
			onChosen: value => Settings.set("sounds", "volume", value)
		}
	}

	Card {
		width: parent.width
		title: "What has one"

		Setting {
			text: "Notifications"
			checked: Settings.sounds.notifications
			onToggled: wanted => Settings.set("sounds", "notifications", wanted)
		}

		Setting {
			text: "Changing the volume"
			checked: Settings.sounds.volumeChange
			onToggled: wanted => Settings.set("sounds", "volumeChange", wanted)
		}

		Setting {
			text: "The charger going in or out"
			checked: Settings.sounds.power
			onToggled: wanted => Settings.set("sounds", "power", wanted)
		}

		Setting {
			text: "Screenshots"
			checked: Settings.sounds.screenshots
			onToggled: wanted => Settings.set("sounds", "screenshots", wanted)
		}
	}
}
