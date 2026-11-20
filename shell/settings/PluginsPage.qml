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

			// A plugin, and under it, while it's on, what it has to set.
			Column {
				id: plugin

				required property var modelData

				width: parent.width
				spacing: Theme.u(6)

				Setting {
					holds: "plugins.enabled"
					words: "plugin addon extension"
					text: plugin.modelData.name
					subtext: plugin.modelData.trouble || [plugin.modelData.description, [plugin.modelData.bar ? "a part for the bar" : "", plugin.modelData.background ? "runs with the shell" : "", plugin.modelData.launcher || plugin.modelData.modes.length > 0 ? "modes for the launcher" : ""].filter(part => part !== "").join(", ")].filter(part => part !== "").join(" · ")
					enabled: !plugin.modelData.trouble
					checked: plugin.modelData.on
					onToggled: wanted => Plugins.enable(plugin.modelData.id, wanted)
				}

				Repeater {
					model: plugin.modelData.on ? plugin.modelData.settings : []

					Loader {
						id: option

						required property var modelData
						readonly property var value: Plugins.option(plugin.modelData.id, modelData.key)

						function keep(value) {
							Plugins.setOption(plugin.modelData.id, modelData.key, value);
						}

						x: Theme.u(16)
						width: parent.width - x
						sourceComponent: ({ toggle: toggleOption, text: textOption, number: numberOption, choice: choiceOption })[modelData.type]

						Component {
							id: toggleOption

							Setting {
								holds: "plugins.options"
								text: option.modelData.text
								subtext: option.modelData.subtext
								checked: !!option.value
								onToggled: wanted => option.keep(wanted)
							}
						}

						Component {
							id: textOption

							Field {
								holds: "plugins.options"
								text: option.modelData.text
								subtext: option.modelData.subtext
								value: option.value ?? ""
								onKept: value => option.keep(value)
							}
						}

						Component {
							id: numberOption

							Choice {
								holds: "plugins.options"
								text: option.modelData.text
								subtext: option.modelData.subtext
								values: option.modelData.values.length > 0 ? option.modelData.values : [0, 1, 2, 5, 10]
								value: Number(option.value) || 0
								none: "0"
								onChosen: value => option.keep(value)
							}
						}

						Component {
							id: choiceOption

							Pick {
								holds: "plugins.options"
								text: option.modelData.text
								subtext: option.modelData.subtext
								options: option.modelData.options
								value: option.value
								onChosen: value => option.keep(value)
							}
						}
					}
				}
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
