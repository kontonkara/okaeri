import QtQuick
import qs
import qs.ui

// How loud the volume can go, how loud the shell's sounds are, and what has one.
Column {
	spacing: Math.round(Theme.u(10))

	Card {
		width: parent.width

		Choice {
			holds: "audio.max"
			text: Tr.t("The volume goes up to")
			subtext: Tr.t("Past 100% the sound is made louder, and can crackle")
			values: [100, 125, 150]
			value: Settings.audio.max
			unit: "%"
			onChosen: value => Settings.set("audio", "max", value)
		}
	}

	Card {
		width: parent.width

		Choice {
			holds: "sounds.volume"
			text: Tr.t("Volume of the sounds")
			subtext: Tr.t("They go through the sound theme, freedesktop's")
			values: [0, 10, 15, 20, 25, 30, 40, 50, 75, 100]
			value: Settings.sounds.volume
			none: Tr.t("Off")
			unit: "%"
			onChosen: value => Settings.set("sounds", "volume", value)
		}
	}

	Card {
		width: parent.width
		title: Tr.t("What has one")

		Setting {
			holds: "sounds.notifications"
			text: Tr.t("Notifications")
			checked: Settings.sounds.notifications
			onToggled: wanted => Settings.set("sounds", "notifications", wanted)
		}

		Setting {
			holds: "sounds.volumeChange"
			text: Tr.t("Changing the volume")
			checked: Settings.sounds.volumeChange
			onToggled: wanted => Settings.set("sounds", "volumeChange", wanted)
		}

		Setting {
			holds: "sounds.power"
			text: Tr.t("The charger going in or out")
			checked: Settings.sounds.power
			onToggled: wanted => Settings.set("sounds", "power", wanted)
		}

		Setting {
			holds: "sounds.screenshots"
			text: Tr.t("Screenshots")
			checked: Settings.sounds.screenshots
			onToggled: wanted => Settings.set("sounds", "screenshots", wanted)
		}
	}
}
