import QtQuick
import Quickshell
import qs
import qs.notifications
import qs.ui

// How toasts go, what's kept of them, and what's different for each app.
Flickable {
	id: page

	// The width of a column of switches.
	readonly property real column: Theme.u(72)
	// Those heard from since the shell started, those with a rule, and all of them.
	readonly property var apps: [...new Set(NotificationStore.apps.concat(Settings.notifications.rules.map(rule => rule.app ?? "").filter(app => app !== "")))].sort((a, b) => a.localeCompare(b)).concat([""])
	// The one that's open.
	property string unfolded: "\n"

	function same(rule, app) {
		return (rule.app ?? "").toLowerCase() === app.toLowerCase();
	}

	function rule(app) {
		return Settings.notifications.rules.find(rule => same(rule, app)) ?? {};
	}

	function set(key, value) {
		Settings.set("notifications", key, value);
	}

	// What says nothing new is no rule at all, and one for all apps comes last.
	function change(app, key, wanted) {
		const changed = Object.assign({ app }, rule(app), { [key]: wanted });
		if (wanted === undefined)
			delete changed[key];
		const holds = changed.toast === false || changed.history === false || changed.sound === false || !!changed.bypass || changed.timeout !== undefined || !!changed.text;
		const others = Settings.notifications.rules.filter(rule => !same(rule, app));
		set("rules", (holds ? others.concat([changed]) : others).sort((a, b) => !a.app - !b.app));
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
				onChosen: value => page.set("timeout", value)
			}

			Choice {
				text: "Low ones for"
				values: [1, 2, 3, 4, 5, 6, 8, 10]
				value: Settings.notifications.timeoutLow
				onChosen: value => page.set("timeoutLow", value)
			}

			Choice {
				text: "Critical ones for"
				values: [0, 10, 20, 30, 60, 120, 300]
				value: Settings.notifications.timeoutCritical
				none: "Till closed"
				onChosen: value => page.set("timeoutCritical", value)
			}

			Setting {
				text: "Apps can say how long"
				checked: Settings.notifications.appsDecide
				onToggled: wanted => page.set("appsDecide", wanted)
			}

			Choice {
				text: "At most at once"
				values: [1, 2, 3, 4, 5, 6, 8]
				value: Settings.notifications.cap
				unit: " "
				onChosen: value => page.set("cap", value)
			}

			Pick {
				text: "Where"
				options: [
					{ value: "top-left", text: "Top left" },
					{ value: "top", text: "Top" },
					{ value: "top-right", text: "Top right" },
					{ value: "bottom-left", text: "Bottom left" },
					{ value: "bottom-right", text: "Bottom right" }
				]
				value: Settings.notifications.position
				onChosen: value => page.set("position", value)
			}

			Setting {
				text: "Over fullscreen windows"
				subtext: "Games and video too"
				checked: Settings.notifications.overFullscreen
				onToggled: wanted => page.set("overFullscreen", wanted)
			}

			Setting {
				text: "With their buttons"
				subtext: "The history has them either way"
				checked: Settings.notifications.actions
				onToggled: wanted => page.set("actions", wanted)
			}

			Setting {
				text: "A line for the time left"
				subtext: "Under each: it has all of it again after the pointer was on it"
				checked: Settings.notifications.timeLeft
				onToggled: wanted => page.set("timeLeft", wanted)
			}

			Setting {
				text: "Quiet while the screen is shared"
				subtext: "Critical ones still show"
				checked: Settings.notifications.quietSharing
				onToggled: wanted => page.set("quietSharing", wanted)
			}

			Pick {
				text: "They say"
				subtext: "The history has all of it"
				options: [
					{ value: "all", text: "All of it" },
					{ value: "title", text: "The title" },
					{ value: "none", text: "Who it's from" }
				]
				value: Settings.notifications.toastText
				onChosen: value => page.set("toastText", value)
			}
		}

		Card {
			width: parent.width
			title: "History"

			Setting {
				text: "The same again makes one"
				subtext: "With how many times it came"
				checked: Settings.notifications.stack
				onToggled: wanted => page.set("stack", wanted)
			}

			Setting {
				text: "The bell with nothing new"
				subtext: "Off, it only shows for something unread"
				checked: Settings.notifications.bellAlways
				onToggled: wanted => page.set("bellAlways", wanted)
			}

			Setting {
				text: "How many are unread, on the bell"
				checked: Settings.notifications.bellCount
				onToggled: wanted => page.set("bellCount", wanted)
			}

			Setting {
				text: "Keep it over a restart"
				subtext: "In a file only you can read, without the pictures that came as data"
				checked: Settings.notifications.keep
				onToggled: wanted => page.set("keep", wanted)
			}

			Choice {
				text: "How much of it"
				values: [20, 50, 100, 200, 500]
				value: Settings.notifications.history
				unit: " "
				onChosen: value => page.set("history", value)
			}

			Choice {
				text: "How long it stays"
				values: [0, 1, 3, 7, 14, 30]
				value: Settings.notifications.maxAge
				none: "Always"
				unit: " d"
				onChosen: value => page.set("maxAge", value)
			}
		}

		Card {
			width: parent.width
			title: "Apps"

			Row {
				anchors.right: parent.right

				Heading {
					text: "Toasts"
				}

				Heading {
					text: "History"
				}
			}

			Repeater {
				model: page.apps

				Column {
					id: line

					required property string modelData
					readonly property var held: page.rule(modelData)
					readonly property bool open: page.unfolded === modelData

					width: parent.width
					spacing: Theme.u(6)

					Item {
						width: parent.width
						height: Theme.u(30)

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							onClicked: page.unfolded = line.open ? "\n" : line.modelData
						}

						Icon {
							id: chevron

							anchors.verticalCenter: parent.verticalCenter
							name: "chevron"
							size: Theme.u(14)
							color: Theme.colors.subtext
							rotation: line.open ? 90 : 0
						}

						Text {
							anchors.left: chevron.right
							anchors.leftMargin: Theme.u(6)
							anchors.right: switches.left
							anchors.rightMargin: Theme.u(12)
							anchors.verticalCenter: parent.verticalCenter
							text: line.modelData || "All apps"
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

					Column {
						width: parent.width
						visible: line.open
						spacing: Theme.u(6)

						TextField {
							width: parent.width
							placeholder: "Only when it says this, or /a pattern/, Enter to keep"
							text: line.held.text ?? ""
							onAccepted: page.change(line.modelData, "text", text || undefined)
						}

						Setting {
							text: "Sound"
							checked: line.held.sound !== false
							onToggled: wanted => page.change(line.modelData, "sound", wanted)
						}

						Setting {
							text: "Through Do Not Disturb"
							checked: !!line.held.bypass
							onToggled: wanted => page.change(line.modelData, "bypass", wanted)
						}

						Choice {
							text: "Its toasts stay for"
							values: [0, 3, 5, 10, 15, 30, 60]
							value: line.held.timeout ?? 0
							none: "As above"
							onChosen: value => page.change(line.modelData, "timeout", value || undefined)
						}
					}
				}
			}
		}
	}
}
