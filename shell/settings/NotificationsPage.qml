import QtQuick
import Quickshell
import qs
import qs.notifications
import qs.ui

// How long toasts stay and how many there are, and what each app gets to show.
Flickable {
	id: page

	// The width of a column of switches.
	readonly property real column: Theme.u(72)
	// Those heard from since the shell started, and those with a rule.
	readonly property var apps: [...new Set(NotificationStore.apps.concat(Settings.notifications.rules.map(rule => rule.app)))].sort((a, b) => a.localeCompare(b))

	function rule(app) {
		return Settings.notifications.rules.find(rule => rule.app.toLowerCase() === app.toLowerCase()) ?? {};
	}

	// With nothing held back it's no rule at all.
	function change(app, key, wanted) {
		const others = Settings.notifications.rules.filter(rule => rule.app.toLowerCase() !== app.toLowerCase());
		const changed = Object.assign({ app }, rule(app), { [key]: wanted });
		Settings.set("notifications", "rules", changed.toast === false || changed.history === false ? others.concat([changed]) : others);
	}

	contentHeight: stack.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	component Heading: Text {
		width: page.column
		horizontalAlignment: Text.AlignHCenter
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}

	Glide {
		view: page
	}

	Column {
		id: stack

		width: parent.width
		spacing: Math.round(Theme.u(10))

		Card {
			width: parent.width
			title: "Toasts"

			Choice {
				text: "They stay for"
				subtext: "When the app doesn't say"
				values: [3, 4, 5, 6, 8, 10, 15, 20, 30]
				value: Settings.notifications.timeout
				onChosen: value => Settings.set("notifications", "timeout", value)
			}

			Choice {
				text: "At most at once"
				values: [1, 2, 3, 4, 5, 6, 8]
				value: Settings.notifications.cap
				unit: " up"
				onChosen: value => Settings.set("notifications", "cap", value)
			}
		}

		Card {
			width: parent.width
			title: "Apps"

			Text {
				width: parent.width
				visible: page.apps.length === 0
				text: "Apps show up here as they send something"
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Row {
				anchors.right: parent.right
				visible: page.apps.length > 0

				Heading {
					text: "Toasts"
				}

				Heading {
					text: "History"
				}
			}

			Repeater {
				model: page.apps

				Item {
					id: line

					required property string modelData
					readonly property var held: page.rule(modelData)

					width: parent.width
					height: Theme.u(30)

					Text {
						anchors.left: parent.left
						anchors.right: switches.left
						anchors.rightMargin: Theme.u(12)
						anchors.verticalCenter: parent.verticalCenter
						text: line.modelData
						textFormat: Text.PlainText
						color: Theme.colors.text
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Row {
						id: switches

						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter

						Item {
							width: page.column
							height: toast.height

							Toggle {
								id: toast

								anchors.horizontalCenter: parent.horizontalCenter
								checked: line.held.toast !== false
								onToggled: wanted => page.change(line.modelData, "toast", wanted)
							}
						}

						Item {
							width: page.column
							height: history.height

							Toggle {
								id: history

								anchors.horizontalCenter: parent.horizontalCenter
								checked: line.held.history !== false
								onToggled: wanted => page.change(line.modelData, "history", wanted)
							}
						}
					}
				}
			}
		}
	}
}
