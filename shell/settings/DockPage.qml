import QtQuick
import Quickshell
import qs
import qs.launcher
import qs.ui

// The dock: whether there's one, where, how large, whether it hides, the screens
// it's on if there are more than one, and the apps it keeps, which an app's menu
// puts there, in the launcher or on the dock.
Flickable {
	id: page

	// The dock whose settings show: a screen's, by its name, or with "" every
	// screen's. What's set for a screen is that screen's own, over every screen's.
	property string forScreen: ""
	readonly property var own: Settings.dockOf(forScreen)
	// The screens there are, and those left without a dock that aren't there now.
	readonly property var screens: {
		const there = Quickshell.screens.map(screen => ({
			name: screen.name,
			about: [screen.model, `${screen.width}×${screen.height}`].filter(part => !!part).join(" · ")
		}));
		const gone = own.hideOn.filter(name => !there.some(screen => screen.name === name)).map(name => ({ name, about: "Not connected" }));
		return there.concat(gone);
	}

	function showOn(name, wanted) {
		const others = own.hideOn.filter(other => other !== name);
		Settings.set("dock", "hideOn", wanted ? others : others.concat([name]));
	}

	contentHeight: column.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	Glide {
		view: page
	}

	Column {
		id: column

		width: parent.width
		spacing: Math.round(Theme.u(10))

		Card {
			width: parent.width

			// With more screens than one, each dock can have settings of its own.
			Item {
				width: parent.width
				height: whichDock.height
				visible: Quickshell.screens.length > 1 || Object.keys(Settings.dock.screens ?? {}).length > 0

				Pick {
					id: whichDock

					holds: "dock.screens"
					words: "monitor screen several docks"
					width: parent.width - (likeOthers.visible ? likeOthers.width + Theme.u(8) : 0)
					text: Tr.t("The dock of")
					subtext: page.forScreen ? Tr.t("What's set here is that screen's own") : ""
					options: [{ value: "", text: Tr.t("Every screen") }].concat([...new Set(Quickshell.screens.map(screen => screen.name).concat(Object.keys(Settings.dock.screens ?? {})))].map(name => ({ value: name, text: name })))
					value: page.forScreen
					onChosen: value => page.forScreen = value
				}

				Button {
					id: likeOthers

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					height: Theme.u(30)
					visible: page.forScreen !== "" && !!Settings.dock.screens?.[page.forScreen]
					flat: true
					text: Tr.t("Like the others")
					onClicked: Settings.dropDock(page.forScreen)
				}
			}

			Setting {
				holds: "dock.on"
				visible: page.forScreen === ""
				text: Tr.t("A dock")
				subtext: Tr.t("The apps it keeps, and those with windows: a click goes to one")
				checked: page.own.on
				onToggled: wanted => Settings.set("dock", "on", wanted)
			}

			Pick {
				holds: "dock.position"
				text: Tr.t("It's at")
				subtext: Tr.t("In the middle of that edge")
				options: [
					{ value: "bottom", text: Tr.t("The bottom") },
					{ value: "left", text: Tr.t("The left") },
					{ value: "right", text: Tr.t("The right") },
					{ value: "top", text: Tr.t("The top") }
				]
				value: page.own.position
				onChosen: value => Settings.setDock(page.forScreen, "position", value)
			}

			Setting {
				holds: "dock.autoHide"
				text: Tr.t("It hides")
				subtext: Tr.t("Over the windows, until the pointer rests at its edge, or the overview opens")
				checked: page.own.autoHide
				onToggled: wanted => Settings.setDock(page.forScreen, "autoHide", wanted)
			}

			Choice {
				holds: "dock.size"
				text: Tr.t("Its icons")
				values: [28, 32, 40, 48, 56, 64]
				value: page.own.size
				unit: " px"
				onChosen: value => Settings.setDock(page.forScreen, "size", value)
			}

			Pick {
				holds: "dock.windows"
				text: Tr.t("Apps with windows")
				subtext: page.own.windows === "pinned" ? Tr.t("Only those it keeps, with their windows") : page.own.windows === "screen" ? Tr.t("Those with a window on its screen") : Tr.t("All of them, on every screen's dock")
				options: [
					{ value: "all", text: Tr.t("All") },
					{ value: "screen", text: Tr.t("Its screen's") },
					{ value: "pinned", text: Tr.t("None") }
				]
				value: page.own.windows
				onChosen: value => Settings.setDock(page.forScreen, "windows", value)
			}

			Choice {
				holds: "dock.magnify"
				words: "zoom magnification"
				text: Tr.t("Icons grow under the pointer")
				subtext: Tr.t("To this much, and those beside them make room")
				values: [0, 120, 140, 160, 180, 200]
				value: page.own.magnify
				none: Tr.t("No")
				unit: "%"
				onChosen: value => Settings.setDock(page.forScreen, "magnify", value)
			}

			Setting {
				holds: "dock.bounce"
				words: "jump launching"
				text: Tr.t("Apps move")
				subtext: Tr.t("As one starts, until its window comes, and while it asks to be looked at")
				checked: page.own.bounce
				onToggled: wanted => Settings.setDock(page.forScreen, "bounce", wanted)
			}

			Pick {
				holds: "dock.motion"
				words: "animation launch jump"
				visible: page.own.bounce
				text: Tr.t("How")
				options: [
					{ value: "bounce", text: Tr.t("Up and down") },
					{ value: "pulse", text: Tr.t("Larger and back") },
					{ value: "wiggle", text: Tr.t("Side to side") }
				]
				value: page.own.motion
				valueWidth: Theme.u(140)
				onChosen: value => Settings.setDock(page.forScreen, "motion", value)
			}

			Pick {
				holds: "dock.indicator"
				words: "running dot line mark"
				text: Tr.t("An app with windows has")
				options: [
					{ value: "dot", text: Tr.t("A dot") },
					{ value: "line", text: Tr.t("A line") },
					{ value: "dots", text: Tr.t("A dot for each") },
					{ value: "none", text: Tr.t("Nothing") }
				]
				value: page.own.indicator
				valueWidth: Theme.u(140)
				onChosen: value => Settings.setDock(page.forScreen, "indicator", value)
			}

			Setting {
				holds: "dock.count"
				text: Tr.t("How many windows")
				subtext: Tr.t("A number on an app with more than one")
				checked: page.own.count
				onToggled: wanted => Settings.setDock(page.forScreen, "count", wanted)
			}

			Setting {
				holds: "dock.unread"
				text: Tr.t("Unread notifications")
				subtext: Tr.t("How many, on the app they're from")
				checked: page.own.unread
				onToggled: wanted => Settings.setDock(page.forScreen, "unread", wanted)
			}

			Setting {
				holds: "dock.progress"
				words: "launcherentry download badge count"
				text: Tr.t("What apps say they're doing")
				subtext: Tr.t("How far a download or a copy is along, and counts of their own")
				checked: page.own.progress
				onToggled: wanted => Settings.setDock(page.forScreen, "progress", wanted)
			}

			Setting {
				holds: "dock.separator"
				text: Tr.t("A line after those kept")
				subtext: Tr.t("Before the others with windows")
				checked: page.own.separator
				onToggled: wanted => Settings.setDock(page.forScreen, "separator", wanted)
			}

			Pick {
				holds: "dock.launcher"
				text: Tr.t("A button for the launcher")
				options: [
					{ value: "none", text: Tr.t("No") },
					{ value: "start", text: Tr.t("First") },
					{ value: "end", text: Tr.t("Last") }
				]
				value: page.own.launcher
				onChosen: value => Settings.setDock(page.forScreen, "launcher", value)
			}

			Setting {
				holds: "dock.smartHide"
				text: Tr.t("In sight on an empty workspace")
				subtext: Tr.t("Where it hides: over no windows there's nothing to hide it for")
				enabled: page.own.autoHide
				checked: page.own.smartHide
				onToggled: wanted => Settings.setDock(page.forScreen, "smartHide", wanted)
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Screens")
			visible: page.screens.length > 1

			Repeater {
				model: page.screens

				Setting {
					required property var modelData

					text: modelData.name
					subtext: modelData.about
					checked: !page.own.hideOn.includes(modelData.name)
					onToggled: wanted => page.showOn(modelData.name, wanted)
				}
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Kept on it")

			Text {
				width: parent.width
				visible: page.own.pinned.length === 0
				wrapMode: Text.WordWrap
				text: Tr.t("None yet: a right click on an app in the dock has a menu that keeps it there, and so does its menu in the launcher. One that's kept goes where it's dragged along the dock.")
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Repeater {
				model: page.own.pinned

				Setting {
					required property string modelData
					required property int index
					readonly property var entry: Apps.find(modelData)

					text: entry?.name ?? modelData
					image: entry ? Apps.image(entry.icon) : ""
					checked: true
					movable: index > 0
					onToggled: wanted => Apps.dock(modelData, wanted)
					onRaised: Apps.raise("dock", modelData)
				}
			}
		}
	}
}
