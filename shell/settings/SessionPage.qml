import QtQuick
import qs
import qs.services
import qs.ui

// When the session locks, the screens go off and the machine sleeps by
// themselves, what's in the session menu and the time left there to change your
// mind, the files other apps take the colors from, commands of yours for when
// things happen, and what a battery changes: when it's said to be low, and how
// soon things happen on it.
Flickable {
	id: page

	readonly property var waits: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600]
	// Each a template and the file it's written to: see hooks/Templates.qml.
	readonly property var templates: Array.isArray(Settings.hooks.templates) ? Settings.hooks.templates : []

	function show(action, wanted) {
		const others = Settings.session.hidden.filter(other => other !== action);
		Settings.set("session", "hidden", wanted ? others : others.concat([action]));
	}

	// A file is written where it's a whole path, or one in the home folder.
	function whole(path) {
		return /^(\/|~\/)/.test(path);
	}

	function addTemplate(from, to) {
		Settings.set("hooks", "templates", templates.concat([{ from, to }]));
	}

	function changeTemplate(at, key, value) {
		Settings.set("hooks", "templates", templates.map((own, index) => index === at ? Object.assign({}, own, { [key]: value }) : own));
	}

	function removeTemplate(at) {
		Settings.set("hooks", "templates", templates.filter((own, index) => index !== at));
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

			Field {
				text: "Locking is"
				subtext: "A command, where the lock screen doesn't listen to the session"
				placeholder: "loginctl lock-session"
				value: Settings.session.lock
				onKept: value => Settings.set("session", "lock", value)
			}

			Setting {
				text: "Lock before sleeping"
				subtext: "When the session menu, the launcher or idle puts it to sleep"
				checked: Settings.session.lockFirst
				onToggled: wanted => Settings.set("session", "lockFirst", wanted)
			}

			Choice {
				text: "Screens off once it's locked"
				subtext: "With nothing going on for that long, by any lock screen that says so"
				values: [0, 10, 30, 60, 120]
				value: Settings.idle.lockedScreenOff
				none: "Don't"
				onChosen: value => Settings.set("idle", "lockedScreenOff", value)
			}
		}

		// Over the commands, which can have the apps read them again.
		Card {
			width: parent.width
			title: "Colors for other apps"

			Text {
				width: parent.width
				wrapMode: Text.WordWrap
				text: "Each template is written to its file as the colors change, with {{accent}} in it as #rrggbb, {{accent.strip}} without the #, {{accent.rgb}} as r, g, b, the same for the other colors, and {{mode}} as light or dark. Those that come with okaeri go by their names alone: kitty.conf, foot.ini, alacritty.toml, gtk3.css, gtk4.css and fuzzel.ini."
				textFormat: Text.PlainText
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			// By how many there are: a change to one doesn't make the rows anew, and
			// take away the field that's next to be typed in.
			Repeater {
				model: page.templates.length

				Row {
					id: line

					required property int index
					readonly property var own: page.templates[index] ?? ({})
					// The two fields share what the button leaves, in whole pixels.
					readonly property int half: Math.floor((width - remover.width - spacing * 2) / 2)

					width: parent.width
					spacing: Math.round(Theme.u(8))

					TextField {
						width: line.half
						implicitHeight: Theme.u(32)
						placeholder: "Template"
						text: line.own.from ?? ""
						keeps: true
						wrong: text.trim() === ""
						onAccepted: {
							if (text.trim() !== "")
								page.changeTemplate(line.index, "from", text.trim());
						}
					}

					TextField {
						width: line.half
						implicitHeight: Theme.u(32)
						placeholder: "Written to"
						text: line.own.to ?? ""
						keeps: true
						wrong: !page.whole(text.trim())
						onAccepted: {
							if (page.whole(text.trim()))
								page.changeTemplate(line.index, "to", text.trim());
						}
					}

					Button {
						id: remover

						height: Math.round(Theme.u(32))
						flat: true
						icon: "trash"
						tip: "Remove it"
						onClicked: page.removeTemplate(line.index)
					}
				}
			}

			Row {
				id: adding

				readonly property int half: Math.floor((width - adder.width - spacing * 2) / 2)
				readonly property bool filled: newFrom.text.trim() !== "" && page.whole(newTo.text.trim())

				function add() {
					if (!filled)
						return;
					page.addTemplate(newFrom.text.trim(), newTo.text.trim());
					newFrom.text = "";
					newTo.text = "";
				}

				width: parent.width
				spacing: Math.round(Theme.u(8))

				TextField {
					id: newFrom

					width: adding.half
					implicitHeight: Theme.u(32)
					placeholder: "A template: kitty.conf"
					// On to where it's written, unless that's there already.
					onAccepted: {
						if (adding.filled)
							adding.add();
						else
							newTo.take();
					}
				}

				TextField {
					id: newTo

					width: adding.half
					implicitHeight: Theme.u(32)
					placeholder: "~/.config/kitty/okaeri.conf"
					wrong: text.trim() !== "" && !page.whole(text.trim())
					onAccepted: adding.add()
				}

				Button {
					id: adder

					height: Math.round(Theme.u(32))
					icon: "plus"
					tip: "Add it"
					enabled: adding.filled
					onClicked: adding.add()
				}
			}
		}

		Card {
			width: parent.width
			title: "Commands"

			Text {
				width: parent.width
				wrapMode: Text.WordWrap
				text: "Run when that happens. What it's about is in the command's environment: OKAERI_CHARGE, OKAERI_LIGHT, OKAERI_PALETTE and OKAERI_COLOR_ACCENT with the other colors, OKAERI_WALLPAPER."
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
