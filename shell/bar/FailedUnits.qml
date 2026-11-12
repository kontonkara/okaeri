import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// When systemd units failed: how many, and a click says which, each with a way
// to start it again, to take its failure off the list and to see what its
// journal said last, and with more than one a way to take them all off.
BarButton {
	id: button

	readonly property bool wanted: Units.failed.length > 0

	visible: wanted
	icon: "alert"
	text: `${Units.failed.length}`
	tip: Units.failed.length === 1 ? "A unit failed" : `${Units.failed.length} units failed`
	ink: Theme.colors.error
	onClicked: {
		Units.check();
		list.middle = Panels.middleOf(button);
		list.show(button.QsWindow.window.screen);
	}
	onWantedChanged: {
		if (!wanted)
			list.hide();
	}

	component Line: Text {
		width: parent.width
		textFormat: Text.PlainText
		elide: Text.ElideRight
		font.family: Theme.font
	}

	Panel {
		id: list

		align: "top"
		panelWidth: Theme.u(320)

		Repeater {
			model: Units.failed

			Column {
				id: failure

				required property var modelData
				// Its journal's last lines, shown under it.
				property bool why: false

				width: parent.width
				spacing: Theme.u(2)

				Line {
					text: modelData.unit
					color: Theme.colors.text
					font.pixelSize: Theme.fontSize
					font.weight: Theme.fontWeight
				}

				Line {
					text: `${modelData.user ? "User" : "System"} · ${modelData.description}`
					color: Theme.colors.subtext
					font.pixelSize: Theme.fontSize - Theme.u(1)
				}

				Line {
					visible: Units.trouble?.unit === modelData.unit
					text: Units.trouble?.text ?? ""
					color: Theme.colors.error
					font.pixelSize: Theme.fontSize - Theme.u(1)
				}

				Row {
					spacing: Theme.u(6)

					Button {
						height: Theme.u(26)
						pad: Theme.u(10)
						text: "Restart"
						onClicked: Units.act(modelData, "restart")
					}

					Button {
						height: Theme.u(26)
						pad: Theme.u(10)
						flat: true
						text: "Clear"
						tip: "Off this list, as it is"
						onClicked: Units.act(modelData, "clear")
					}

					Button {
						height: Theme.u(26)
						pad: Theme.u(10)
						flat: true
						text: failure.why ? "Less" : "Why"
						tip: "What its journal said last"
						onClicked: {
							failure.why = !failure.why;
							if (failure.why)
								Units.explain(failure.modelData);
						}
					}
				}

				// As the journal has it: what the unit printed, a line each.
				Text {
					width: parent.width
					visible: failure.why
					text: Units.told[failure.modelData.unit] ?? "Reading its journal..."
					textFormat: Text.PlainText
					wrapMode: Text.WrapAnywhere
					maximumLineCount: 8
					elide: Text.ElideRight
					color: Theme.colors.subtext
					font.family: "monospace"
					font.pixelSize: Theme.fontSize - Theme.u(2)
				}
			}
		}

		// With more than one, all of them off the list at once.
		Button {
			visible: Units.failed.length > 1
			height: Theme.u(28)
			flat: true
			text: "Clear all"
			onClicked: Units.failed.forEach(unit => Units.act(unit, "clear"))
		}
	}
}
