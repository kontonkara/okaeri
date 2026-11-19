import QtQuick
import qs
import qs.services
import qs.ui

// A line to pick a color: `text`, `subtext` if it has one, and `value`, "" for
// none of its own, "accent" for the theme's, or "#rrggbb". A dot is one of a
// few, the pipette takes one off the screen, and the field any other:
// chosen(value) says which.
Item {
	id: shade

	required property string text
	// What it sets, for its mark, and more words the search finds it by.
	property string holds
	property string words
	property string subtext
	property string value
	// What "" shows as.
	property color none: Theme.colors.text
	readonly property var dots: ["", "accent", "#e06c75", "#e5c07b", "#98c379", "#61afef", "#a98bf0"]
	// While the pipette waits for its click.
	property bool picking: false

	signal chosen(string value)

	width: parent.width
	height: Theme.u(subtext ? 40 : 34)

	Connections {
		target: Niri
		enabled: shade.picking

		function onColorPicked(color) {
			shade.picking = false;
			shade.chosen(color);
		}
	}

	// A click taken back says nothing.
	Timer {
		running: shade.picking
		interval: 30000
		onTriggered: shade.picking = false
	}

	Column {
		anchors.left: parent.left
		anchors.right: tools.left
		anchors.rightMargin: Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter

		Text {
			width: parent.width
			text: shade.text
			color: Theme.colors.text
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Text {
			width: parent.width
			visible: text !== ""
			text: shade.subtext
			textFormat: Text.PlainText
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	Row {
		id: tools

		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.u(6)

		Repeater {
			model: shade.dots

			Rectangle {
				required property string modelData
				readonly property bool on: shade.value === modelData

				anchors.verticalCenter: parent.verticalCenter
				objectName: `dot-${modelData || "none"}`
				width: Theme.u(20)
				height: width
				radius: Theme.round(height)
				color: Theme.shade(modelData, shade.none)
				border.width: on ? Theme.u(2.5) : 1
				border.color: on ? Theme.colors.text : Qt.alpha(Theme.colors.text, 0.3)

				// None of its own has a line through it.
				Rectangle {
					anchors.centerIn: parent
					visible: parent.modelData === ""
					width: parent.width * 0.8
					height: Math.max(1, Theme.u(1.5))
					rotation: -45
					color: Theme.colors.background
				}

				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					onClicked: shade.chosen(parent.modelData)
				}
			}
		}

		Button {
			objectName: "pipette"
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(30)
			flat: true
			icon: "pipette"
			ink: shade.picking ? Theme.colors.accent : Theme.colors.text
			tip: Tr.t("Take one off the screen")
			onClicked: {
				shade.picking = true;
				Env.act("color pick", () => Niri.pickColor());
			}
		}

		TextField {
			objectName: "field"
			anchors.verticalCenter: parent.verticalCenter
			implicitWidth: Theme.u(96)
			implicitHeight: Theme.u(32)
			placeholder: "#rrggbb"
			text: shade.value.startsWith("#") ? shade.value : ""
			keeps: true
			onAccepted: {
				const wanted = text.trim().replace(/^([0-9a-fA-F]{6})$/, "#$1").toLowerCase();
				if (wanted === "" || /^#[0-9a-f]{6}$/.test(wanted))
					shade.chosen(wanted);
			}
		}
	}

	Mark {
		holds: shade.holds
	}
}
