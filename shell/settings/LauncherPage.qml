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
				holds: "launcher.usage"
				text: Tr.t("Frequent apps first")
				subtext: Tr.t("What's launched often comes up sooner")
				checked: Settings.launcher.usage
				onToggled: wanted => Settings.set("launcher", "usage", wanted)
			}

			Setting {
				holds: "launcher.sums"
				text: Tr.t("Keep the last sums")
				subtext: Tr.t("They're under /calc, turning this off forgets them")
				checked: Settings.launcher.sums
				onToggled: wanted => {
					Settings.set("launcher", "sums", wanted);
					if (!wanted)
						Calculator.forget();
				}
			}

			Field {
				holds: "launcher.files"
				text: Tr.t("Files are looked for in")
				subtext: Tr.t("Under /file: a folder, empty for your home")
				placeholder: "~"
				value: Settings.launcher.files
				onKept: value => Settings.set("launcher", "files", value.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
			}

			Setting {
				holds: "launcher.actions"
				text: Tr.t("Apps' own actions in the search")
				subtext: Tr.t("New private window and such, by their names")
				checked: Settings.launcher.actions
				onToggled: wanted => Settings.set("launcher", "actions", wanted)
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Pinned")

			Text {
				width: parent.width
				visible: Settings.launcher.pinned.length === 0
				text: Tr.t("A right click on an app in the launcher pins it")
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Repeater {
				model: Settings.launcher.pinned

				App {
					required property int index

					checked: true
					movable: index > 0
					onToggled: wanted => Apps.pin(modelData, wanted)
					onRaised: Apps.raise("launcher", modelData)
				}
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Hidden")

			Text {
				width: parent.width
				visible: Settings.launcher.hidden.length === 0
				text: Tr.t("A right click on an app in the launcher hides it")
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

		// The groups apps go by in the launcher: the kinds they say they are, and
		// folders of one's own, which an app goes into from its menu there.
		Card {
			width: parent.width
			title: Tr.t("Groups")

			Setting {
				holds: "launcher.categories"
				words: "category folder sort games programming design"
				text: Tr.t("Apps by their kind")
				subtext: Tr.t("Games, Programming, Design and the like, by the button in its field or Ctrl+G")
				checked: Settings.launcher.categories
				onToggled: wanted => Settings.set("launcher", "categories", wanted)
			}

			Field {
				text: Tr.t("A folder of your own")
				subtext: Tr.t("By a name; an app goes into it from its menu in the launcher")
				words: "group category"
				placeholder: Tr.t("Work")
				fieldWidth: Theme.u(160)
				value: ""
				onKept: value => Apps.addFolder(value.trim())
			}

			Repeater {
				model: Apps.folders

				Item {
					required property var modelData
					readonly property int apps: Array.isArray(modelData.apps) ? modelData.apps.length : 0

					width: parent.width
					height: Theme.u(40)

					Column {
						anchors.left: parent.left
						anchors.right: drop.left
						anchors.rightMargin: Theme.u(12)
						anchors.verticalCenter: parent.verticalCenter

						Text {
							width: parent.width
							text: parent.parent.modelData.name
							textFormat: Text.PlainText
							elide: Text.ElideRight
							color: Theme.colors.text
							font.family: Theme.font
							font.pixelSize: Theme.fontSize
						}

						Text {
							width: parent.width
							text: parent.parent.apps === 1 ? "1 app" : `${parent.parent.apps} apps`
							color: Theme.colors.subtext
							font.family: Theme.font
							font.pixelSize: Theme.fontSize - Theme.u(2)
						}
					}

					Button {
						id: drop

						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						height: Theme.u(28)
						flat: true
						icon: "trash"
						tip: Tr.t("Away with the folder; its apps stay")
						onClicked: Apps.dropFolder(parent.modelData.name)
					}
				}
			}
		}

		// Where a ? in front looks things up.
		Card {
			width: parent.width
			title: Tr.t("The web")

			Field {
				holds: "launcher.search"
				words: "web engine google duckduckgo"
				text: Tr.t("A ? looks things up at")
				subtext: Tr.t("An address with %s for the words; > runs a command")
				fieldWidth: Theme.u(260)
				value: Settings.launcher.search
				onKept: value => {
					if (value.includes("%s"))
						Settings.set("launcher", "search", value.trim());
				}
			}
		}
	}
}
