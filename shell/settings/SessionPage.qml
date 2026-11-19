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

	// Those the files leave out, for each line's mark.
	readonly property var fileHidden: Settings.inFiles("session", "hidden") ?? []

	function show(action, wanted) {
		const others = Settings.session.hidden.filter(other => other !== action);
		Settings.setNames("session", "hidden", wanted ? others : others.concat([action]));
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
			title: Tr.t("With nothing going on")

			Choice {
				holds: "idle.lock"
				words: "locker screen lock"
				text: Tr.t("Lock the session")
				values: page.waits
				value: Settings.idle.lock
				onChosen: value => Settings.set("idle", "lock", value)
			}

			Choice {
				holds: "idle.screenOff"
				text: Tr.t("Turn the screens off")
				values: page.waits
				value: Settings.idle.screenOff
				onChosen: value => Settings.set("idle", "screenOff", value)
			}

			Choice {
				holds: "idle.fade"
				text: Tr.t("Fade out before that")
				values: [0, 3, 5, 10, 15, 30]
				value: Settings.idle.fade
				none: Tr.t("Don't")
				onChosen: value => Settings.set("idle", "fade", value)
			}

			Choice {
				holds: "idle.suspend"
				words: "sleep"
				text: Tr.t("Put the machine to sleep")
				subtext: Session.canSuspend ? Tr.t("Suspend, from when nothing went on") : Tr.t("Suspend, which logind says this machine can't now")
				values: page.waits
				value: Settings.idle.suspend
				onChosen: value => Settings.set("idle", "suspend", value)
			}

			Pick {
				holds: "idle.suspendOn"
				text: Tr.t("Sleep when")
				visible: Settings.idle.suspend > 0 || Settings.idle.batterySuspend > 0
				options: [
					{ value: "always", text: Tr.t("Always") },
					{ value: "battery", text: Tr.t("On battery") }
				]
				value: Settings.idle.suspendOn
				onChosen: value => Settings.set("idle", "suspendOn", value)
			}

			Pick {
				holds: "idle.sleepAs"
				words: "hibernate"
				text: Tr.t("It sleeps as")
				subtext: Settings.idle.sleepAs === "suspend-then-hibernate" ? (Session.canSuspendThenHibernate ? Tr.t("Suspended, and hibernated after a while, as logind is set") : Tr.t("Which logind says this machine can't now: it suspends")) : Settings.idle.sleepAs === "hibernate" && !Session.canHibernate ? Tr.t("Which logind says this machine can't now: it suspends") : ""
				visible: Settings.idle.suspend > 0 || Settings.idle.batterySuspend > 0
				valueWidth: Theme.u(150)
				options: [
					{ value: "suspend", text: Tr.t("Suspended") },
					{ value: "suspend-then-hibernate", text: Tr.t("Then hibernated") },
					{ value: "hibernate", text: Tr.t("Hibernated") }
				]
				value: Settings.idle.sleepAs
				onChosen: value => Settings.set("idle", "sleepAs", value)
			}

			Setting {
				holds: "idle.playingHolds"
				text: Tr.t("Not while something plays")
				subtext: Tr.t("Music keeps it up, with the screens off")
				visible: Settings.idle.suspend > 0 || Settings.idle.batterySuspend > 0
				checked: Settings.idle.playingHolds
				onToggled: wanted => Settings.set("idle", "playingHolds", wanted)
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Session menu")

			Choice {
				holds: "session.countdown"
				text: Tr.t("Wait before going ahead")
				subtext: Tr.t("Time to cancel a shutdown or a logout")
				values: [0, 3, 5, 10, 15, 30]
				value: Settings.session.countdown
				none: Tr.t("Don't")
				onChosen: value => Settings.set("session", "countdown", value)
			}

			Repeater {
				model: Session.known

				Setting {
					required property var modelData

					holds: "session.hidden"
					differs: page.fileHidden.includes(modelData.action) !== Settings.session.hidden.includes(modelData.action)
					back: () => page.show(modelData.action, !page.fileHidden.includes(modelData.action))
					text: modelData.text
					subtext: modelData.can ? "" : Tr.t("Not on this machine")
					enabled: modelData.can
					checked: modelData.can && !Settings.session.hidden.includes(modelData.action)
					onToggled: wanted => page.show(modelData.action, wanted)
				}
			}

			Field {
				holds: "session.lock"
				text: Tr.t("Locking is")
				subtext: Tr.t("A command, where the lock screen doesn't listen to the session")
				placeholder: "loginctl lock-session"
				value: Settings.session.lock
				onKept: value => Settings.set("session", "lock", value)
			}

			Setting {
				holds: "session.lockFirst"
				text: Tr.t("Lock before sleeping")
				subtext: Tr.t("When the session menu, the launcher or idle puts it to sleep")
				checked: Settings.session.lockFirst
				onToggled: wanted => Settings.set("session", "lockFirst", wanted)
			}

			Choice {
				holds: "idle.lockedScreenOff"
				text: Tr.t("Screens off once it's locked")
				subtext: Tr.t("With nothing going on for that long, by any lock screen that says so")
				values: [0, 10, 30, 60, 120]
				value: Settings.idle.lockedScreenOff
				none: Tr.t("Don't")
				onChosen: value => Settings.set("idle", "lockedScreenOff", value)
			}
		}

		// The mode for games: what it turns off, and whether gamemode has it on.
		Card {
			width: parent.width
			title: Tr.t("Game mode")

			Setting {
				holds: "game.follow"
				words: "gamemode feral gaming"
				text: Tr.t("On while gamemode has a game")
				subtext: Tr.t("As gamemoderun starts one; its tile and okaeri game toggle have it on by hand")
				checked: Settings.game.follow
				onToggled: wanted => Settings.set("game", "follow", wanted)
			}

			Setting {
				holds: "game.plain"
				text: Tr.t("Nothing moves or is blurred")
				subtext: Tr.t("While it's on")
				checked: Settings.game.plain
				onToggled: wanted => Settings.set("game", "plain", wanted)
			}

			Setting {
				holds: "game.quiet"
				text: Tr.t("Notifications wait")
				subtext: Tr.t("As with Do Not Disturb: critical ones still show")
				checked: Settings.game.quiet
				onToggled: wanted => Settings.set("game", "quiet", wanted)
			}

			Setting {
				holds: "game.awake"
				text: Tr.t("The machine stays awake")
				subtext: Tr.t("No lock, no screens off, no sleep")
				checked: Settings.game.awake
				onToggled: wanted => Settings.set("game", "awake", wanted)
			}
		}

		// Over the commands, which can have the apps read them again.
		Card {
			width: parent.width
			title: Tr.t("Colors for other apps")

			Text {
				width: parent.width
				wrapMode: Text.WordWrap
				text: Tr.t("Each template is written to its file as the colors change, with {{accent}} in it as #rrggbb, {{accent.strip}} without the #, {{accent.rgb}} as r, g, b, the same for the other colors, and {{mode}} as light or dark. Those that come with okaeri go by their names alone: kitty.conf, foot.ini, alacritty.toml, gtk3.css, gtk4.css and fuzzel.ini.")
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
						placeholder: Tr.t("Template")
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
						placeholder: Tr.t("Written to")
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
						tip: Tr.t("Remove it")
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
					placeholder: Tr.t("A template: kitty.conf")
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
					tip: Tr.t("Add it")
					enabled: adding.filled
					onClicked: adding.add()
				}
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Commands")

			Text {
				width: parent.width
				wrapMode: Text.WordWrap
				text: Tr.t("Run when that happens. What it's about is in the command's environment: OKAERI_CHARGE, OKAERI_LIGHT, OKAERI_PALETTE and OKAERI_COLOR_ACCENT with the other colors, OKAERI_WALLPAPER.")
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Repeater {
				model: [
					{ name: "charger", text: Tr.t("The charger goes in") },
					{ name: "battery", text: Tr.t("The charger comes out") },
					{ name: "low", text: Tr.t("The battery gets low") },
					{ name: "colors", text: Tr.t("The colors change") },
					{ name: "wallpaper", text: Tr.t("The wallpaper changes") }
				]

				Field {
					required property var modelData

					text: modelData.text
					placeholder: Tr.t("A command")
					value: Settings.hooks[modelData.name] ?? ""
					onKept: value => Settings.set("hooks", modelData.name, value)
				}
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Battery")

			Choice {
				holds: "battery.warning"
				text: Tr.t("Warn when it's down to")
				subtext: Tr.t("And again at 5%, to stay on screen")
				values: [0, 5, 10, 15, 20, 25, 30, 40, 50]
				value: Settings.battery.warning
				unit: "%"
				onChosen: value => Settings.set("battery", "warning", value)
			}

			Setting {
				holds: "battery.saver"
				text: Tr.t("Save power from then on")
				subtext: Tr.t("The saver profile, until the charger is in")
				checked: Settings.battery.saver
				onToggled: wanted => Settings.set("battery", "saver", wanted)
			}

			Choice {
				holds: "idle.batteryLock"
				text: Tr.t("On it, lock after")
				values: page.waits
				value: Settings.idle.batteryLock
				none: Tr.t("The same")
				onChosen: value => Settings.set("idle", "batteryLock", value)
			}

			Choice {
				holds: "idle.batteryScreenOff"
				text: Tr.t("On it, screens off after")
				values: page.waits
				value: Settings.idle.batteryScreenOff
				none: Tr.t("The same")
				onChosen: value => Settings.set("idle", "batteryScreenOff", value)
			}

			Choice {
				holds: "idle.batterySuspend"
				text: Tr.t("On it, sleep after")
				subtext: Tr.t("Even where it doesn't sleep on the charger")
				values: page.waits
				value: Settings.idle.batterySuspend
				none: Tr.t("The same")
				onChosen: value => Settings.set("idle", "batterySuspend", value)
			}
		}
	}
}
