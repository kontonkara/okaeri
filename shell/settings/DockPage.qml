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

	readonly property var own: Settings.dock
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

			Setting {
				text: "A dock"
				subtext: "The apps it keeps, and those with windows: a click goes to one"
				checked: page.own.on
				onToggled: wanted => Settings.set("dock", "on", wanted)
			}

			Pick {
				text: "It's at"
				subtext: "In the middle of that edge"
				options: [
					{ value: "bottom", text: "The bottom" },
					{ value: "left", text: "The left" },
					{ value: "right", text: "The right" },
					{ value: "top", text: "The top" }
				]
				value: page.own.position
				onChosen: value => Settings.set("dock", "position", value)
			}

			Setting {
				text: "It hides"
				subtext: "Over the windows, until the pointer rests at its edge, or the overview opens"
				checked: page.own.autoHide
				onToggled: wanted => Settings.set("dock", "autoHide", wanted)
			}

			Choice {
				text: "Its icons"
				values: [28, 32, 40, 48, 56, 64]
				value: page.own.size
				unit: " px"
				onChosen: value => Settings.set("dock", "size", value)
			}

			Pick {
				text: "Apps with windows"
				subtext: page.own.windows === "pinned" ? "Only those it keeps, with their windows" : page.own.windows === "screen" ? "Those with a window on its screen" : "All of them, on every screen's dock"
				options: [
					{ value: "all", text: "All" },
					{ value: "screen", text: "Its screen's" },
					{ value: "pinned", text: "None" }
				]
				value: page.own.windows
				onChosen: value => Settings.set("dock", "windows", value)
			}

			Choice {
				text: "Icons grow under the pointer"
				subtext: "To this much, and those beside them make room"
				values: [0, 120, 140, 160, 180, 200]
				value: page.own.magnify
				none: "No"
				unit: "%"
				onChosen: value => Settings.set("dock", "magnify", value)
			}

			Setting {
				text: "Apps hop"
				subtext: "As one starts, until its window comes, and while it asks to be looked at"
				checked: page.own.bounce
				onToggled: wanted => Settings.set("dock", "bounce", wanted)
			}

			Setting {
				text: "How many windows"
				subtext: "A number on an app with more than one"
				checked: page.own.count
				onToggled: wanted => Settings.set("dock", "count", wanted)
			}

			Pick {
				text: "A button for the launcher"
				options: [
					{ value: "none", text: "No" },
					{ value: "start", text: "First" },
					{ value: "end", text: "Last" }
				]
				value: page.own.launcher
				onChosen: value => Settings.set("dock", "launcher", value)
			}

			Setting {
				text: "In sight on an empty workspace"
				subtext: "Where it hides: over no windows there's nothing to hide it for"
				enabled: page.own.autoHide
				checked: page.own.smartHide
				onToggled: wanted => Settings.set("dock", "smartHide", wanted)
			}
		}

		Card {
			width: parent.width
			title: "Screens"
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
			title: "Kept on it"

			Text {
				width: parent.width
				visible: page.own.pinned.length === 0
				wrapMode: Text.WordWrap
				text: "None yet: a right click on an app in the dock has a menu that keeps it there, and so does its menu in the launcher. One that's kept goes where it's dragged along the dock."
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
