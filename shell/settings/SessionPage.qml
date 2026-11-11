import QtQuick
import qs
import qs.services
import qs.ui

// When the session locks, the screens go off and the machine sleeps by
// themselves, what's in the session menu and the time left there to change your
// mind, commands of yours for when things happen, and what a battery changes:
// when it's said to be low, and how soon things happen on it.
Flickable {
	id: page

	readonly property var waits: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600]

	function show(action, wanted) {
		const others = Settings.session.hidden.filter(other => other !== action);
		Settings.set("session", "hidden", wanted ? others : others.concat([action]));
	}

	contentHeight: column.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds
	// What it can do comes from logind.
	Component.onCompleted: Session.check()

	Glide {
		view: page
	}

	Column {
		id: column

		width: parent.width
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

			Choice {
				text: "Fade out before that"
				values: [0, 3, 5, 10, 15, 30]
				value: Settings.idle.fade
				none: "Don't"
				onChosen: value => Settings.set("idle", "fade", value)
			}

			Choice {
				text: "Put the machine to sleep"
				subtext: Session.canSuspend ? "Suspend, from when nothing went on" : "Suspend, which logind says this machine can't now"
				values: page.waits
				value: Settings.idle.suspend
				onChosen: value => Settings.set("idle", "suspend", value)
			}

			Pick {
				text: "Sleep when"
				visible: Settings.idle.suspend > 0
				options: [
					{ value: "always", text: "Always" },
					{ value: "battery", text: "On battery" }
				]
				value: Settings.idle.suspendOn
				onChosen: value => Settings.set("idle", "suspendOn", value)
			}

			Setting {
				text: "Not while something plays"
				subtext: "Music keeps it up, with the screens off"
				visible: Settings.idle.suspend > 0
				checked: Settings.idle.playingHolds
				onToggled: wanted => Settings.set("idle", "playingHolds", wanted)
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

			Repeater {
				model: Session.known

				Setting {
					required property var modelData

					text: modelData.text
					subtext: modelData.can ? "" : "Not on this machine"
					enabled: modelData.can
					checked: modelData.can && !Settings.session.hidden.includes(modelData.action)
					onToggled: wanted => page.show(modelData.action, wanted)
				}
			}
		}

		Card {
			width: parent.width
			title: "Commands"

			Text {
				width: parent.width
				wrapMode: Text.WordWrap
				text: "Run when that happens, Enter to keep. What it's about is in the command's environment: OKAERI_CHARGE, OKAERI_LIGHT, OKAERI_PALETTE and OKAERI_COLOR_ACCENT with the other colors, OKAERI_WALLPAPER."
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Repeater {
				model: [
					{ name: "charger", text: "The charger goes in" },
					{ name: "battery", text: "The charger comes out" },
					{ name: "low", text: "The battery gets low" },
					{ name: "colors", text: "The colors change" },
					{ name: "wallpaper", text: "The wallpaper changes" }
				]

				Field {
					required property var modelData

					text: modelData.text
					placeholder: "A command"
					value: Settings.hooks[modelData.name] ?? ""
					onKept: value => Settings.set("hooks", modelData.name, value)
				}
			}
		}

		Card {
			width: parent.width
			title: "Battery"

			Choice {
				text: "Warn when it's down to"
				subtext: "And again at 5%, to stay on screen"
				values: [0, 5, 10, 15, 20, 25, 30, 40, 50]
				value: Settings.battery.warning
				unit: "%"
				onChosen: value => Settings.set("battery", "warning", value)
			}

			Setting {
				text: "Save power from then on"
				subtext: "The saver profile, until the charger is in"
				checked: Settings.battery.saver
				onToggled: wanted => Settings.set("battery", "saver", wanted)
			}

			Choice {
				text: "On it, lock after"
				values: page.waits
				value: Settings.idle.batteryLock
				none: "The same"
				onChosen: value => Settings.set("idle", "batteryLock", value)
			}

			Choice {
				text: "On it, screens off after"
				values: page.waits
				value: Settings.idle.batteryScreenOff
				none: "The same"
				onChosen: value => Settings.set("idle", "batteryScreenOff", value)
			}
		}
	}
}
