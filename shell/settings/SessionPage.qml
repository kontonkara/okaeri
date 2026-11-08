import QtQuick
import qs
import qs.services
import qs.ui

// When the session locks and the screens go off by themselves, what's in the
// session menu and the time left there to change your mind, and when the battery
// is said to be low.
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
			title: "Battery"

			Choice {
				text: "Warn when it's down to"
				subtext: "And again at 5%, to stay on screen"
				values: [0, 5, 10, 15, 20, 25, 30, 40, 50]
				value: Settings.battery.warning
				unit: "%"
				onChosen: value => Settings.set("battery", "warning", value)
			}
		}
	}
}
