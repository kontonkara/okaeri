import QtQuick
import qs
import qs.ui

// A page of the control center, in its place while Control.unfolded names it:
// a way back, `icon`, `title` and `summary`, a switch that says toggled(wanted),
// unless `switches` is off, and under them what's put in it. `room` is how tall
// that can get.
Card {
	id: section

	required property string name
	property bool wanted: true
	property string icon
	property string title
	property string summary
	property bool checked: false
	property bool canSwitch: true
	property bool switches: true
	// For what's in it: the panel's room, less the page's own top.
	property real room: 0
	readonly property real roomInside: room - header.height - padding * 2
	readonly property bool unfolded: visible
	default property alias content: rows.data

	signal toggled(bool wanted)

	width: parent.width
	padding: Theme.u(6)
	visible: wanted && Control.unfolded === name

	// Here, not as its own handler: a page has handlers of its own for it.
	Connections {
		target: section

		function onUnfoldedChanged() {
			if (section.unfolded && Control.keyed) {
				Control.keyed = false;
				back.forceActiveFocus();
			}
		}
	}

	Column {
		width: parent.width

		Item {
			id: header

			width: parent.width
			height: Theme.u(48)

			Button {
				id: back

				anchors.left: parent.left
				anchors.verticalCenter: parent.verticalCenter
				height: Theme.u(34)
				flat: true
				icon: "back"
				tip: "Back"
				onClicked: Control.unfolded = ""
			}

			Icon {
				id: glyph

				anchors.left: back.right
				anchors.leftMargin: Theme.u(4)
				anchors.verticalCenter: parent.verticalCenter
				name: section.icon
				color: section.checked || !section.switches ? Theme.colors.text : Theme.colors.subtext
			}

			Column {
				anchors.left: glyph.right
				anchors.leftMargin: Theme.u(12)
				anchors.right: toggle.visible ? toggle.left : parent.right
				anchors.rightMargin: Theme.u(12)
				anchors.verticalCenter: parent.verticalCenter

				Text {
					width: parent.width
					text: section.title
					color: Theme.colors.text
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
					font.weight: Theme.fontWeight
				}

				// It can be a name, which anyone nearby picks.
				Text {
					width: parent.width
					visible: text !== ""
					text: section.summary
					textFormat: Text.PlainText
					maximumLineCount: 1
					color: Theme.colors.subtext
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(2)
				}
			}

			Toggle {
				id: toggle

				anchors.right: parent.right
				anchors.rightMargin: Theme.u(8)
				anchors.verticalCenter: parent.verticalCenter
				visible: section.switches
				enabled: section.canSwitch
				checked: section.checked
				onToggled: wanted => section.toggled(wanted)
			}
		}

		Column {
			id: rows

			width: parent.width
		}
	}
}
