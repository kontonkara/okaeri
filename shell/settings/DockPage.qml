import QtQuick
import qs
import qs.launcher
import qs.ui

// The dock: whether there's one, where, how large, whether it hides, and the
// apps it keeps, which the launcher's menu of an app and a right click on the
// dock put there.
Flickable {
	id: page

	readonly property var own: Settings.dock

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
				subtext: "Over the windows, until the pointer rests at its edge of the screen"
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
		}

		Card {
			width: parent.width
			title: "Kept on it"

			Text {
				width: parent.width
				visible: page.own.pinned.length === 0
				wrapMode: Text.WordWrap
				text: "None yet: a right click on an app in the dock keeps it there, and so does its menu in the launcher."
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Repeater {
				model: page.own.pinned

				Setting {
					required property string modelData
					readonly property var entry: Apps.find(modelData)

					text: entry?.name ?? modelData
					image: entry ? Apps.image(entry.icon) : ""
					checked: true
					onToggled: wanted => Apps.dock(modelData, wanted)
				}
			}
		}
	}
}
