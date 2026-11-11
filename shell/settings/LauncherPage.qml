import QtQuick
import Quickshell
import qs
import qs.launcher
import qs.ui

// How the launcher goes about its rows, and the apps it was told about: a right
// click on one there pins it or hides it, and here it goes back.
Flickable {
	id: page

	contentHeight: column.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	component App: Setting {
		required property string modelData
		readonly property var entry: Apps.find(modelData)

		text: entry?.name ?? modelData
		image: entry ? Apps.image(entry.icon) : ""
	}

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
				text: "Frequent apps first"
				subtext: "What's launched often comes up sooner"
				checked: Settings.launcher.usage
				onToggled: wanted => Settings.set("launcher", "usage", wanted)
			}

			Setting {
				text: "Keep the last sums"
				subtext: "They're under /calc, turning this off forgets them"
				checked: Settings.launcher.sums
				onToggled: wanted => {
					Settings.set("launcher", "sums", wanted);
					if (!wanted)
						Calculator.forget();
				}
			}

			Field {
				text: "Files are looked for in"
				subtext: "Under /file: a folder, Enter to keep, empty for your home"
				placeholder: "~"
				value: Settings.launcher.files
				onKept: value => Settings.set("launcher", "files", value.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
			}
		}

		Card {
			width: parent.width
			title: "Pinned"

			Text {
				width: parent.width
				visible: Settings.launcher.pinned.length === 0
				text: "A right click on an app in the launcher pins it"
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Repeater {
				model: Settings.launcher.pinned

				App {
					checked: true
					onToggled: wanted => Apps.pin(modelData, wanted)
				}
			}
		}

		Card {
			width: parent.width
			title: "Hidden"

			Text {
				width: parent.width
				visible: Settings.launcher.hidden.length === 0
				text: "A right click on an app in the launcher hides it"
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Repeater {
				model: Settings.launcher.hidden

				App {
					checked: false
					onToggled: wanted => Apps.hide(modelData, !wanted)
				}
			}
		}
	}
}
