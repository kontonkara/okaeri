import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The plugins in their folder, each turned on or off: their code is the shell's
// own, so none runs before it's turned on here. What one has for the bar goes on
// it from the Bar page, as any part does.
Flickable {
	id: page

	contentHeight: card.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	Glide {
		view: page
	}

	Card {
		id: card

		width: parent.width

		Text {
			width: parent.width
			text: Tr.f("Each a folder in %1 with its plugin.json. One that's on runs as the shell does, with all it can do: turn on only what you trust.", Plugins.folder.replace(Quickshell.env("HOME"), "~"))
			wrapMode: Text.Wrap
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(1)
		}

		Text {
			width: parent.width
			visible: Plugins.list.length === 0
			topPadding: Theme.u(6)
			bottomPadding: Theme.u(6)
			text: Tr.t("None there yet")
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Repeater {
			model: Plugins.list

			Setting {
				required property var modelData

				holds: "plugins.enabled"
				words: "plugin addon extension"
				text: modelData.name
				subtext: modelData.trouble || [modelData.description, [modelData.bar ? "a part for the bar" : "", modelData.background ? "runs with the shell" : ""].filter(part => part !== "").join(", ")].filter(part => part !== "").join(" · ")
				enabled: !modelData.trouble
				checked: modelData.on
				onToggled: wanted => Plugins.enable(modelData.id, wanted)
			}
		}

		Row {
			spacing: Theme.u(6)

			Button {
				height: Theme.u(30)
				flat: true
				icon: "file"
				text: Tr.t("Open the folder")
				onClicked: Plugins.open()
			}

			Button {
				height: Theme.u(30)
				flat: true
				icon: "refresh"
				text: Tr.t("Look again")
				onClicked: Plugins.look()
			}
		}
	}
}
