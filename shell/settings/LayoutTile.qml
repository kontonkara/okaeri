import QtQuick
import qs
import qs.services
import qs.ui

// A layout of Layouts, drawn small: a screen with its bar where it goes, whole,
// as islands or as capsules, a dot for each part, and the dock if it has one.
// A click takes it.
Rectangle {
	id: tile

	required property var layout
	readonly property var bar: layout.settings.bar
	readonly property bool on: Layouts.current === layout.name
	readonly property bool upright: bar.position === "left" || bar.position === "right"
	// How large things are in it: a part's dot, and the bar across.
	readonly property real dot: Theme.u(4)
	readonly property real across: Theme.u(9)
	readonly property real margin: Theme.u((tile.layout.theme.barMargin ?? 4) / 3)

	objectName: `layout-${layout.name}`
	width: Theme.u(150)
	height: Theme.u(118)
	radius: Math.max(0, Theme.cardRadius - Theme.u(4))
	color: pointer.containsMouse ? Theme.hover : "transparent"
	border.width: on ? Theme.u(2) : 1
	border.color: on ? Theme.colors.accent : Theme.border

	Rectangle {
		id: screen

		x: Theme.u(10)
		y: Theme.u(10)
		width: parent.width - Theme.u(20)
		height: Theme.u(76)
		radius: Theme.u(4)
		color: Qt.alpha(Theme.colors.text, 0.06)
		clip: true

		// The bar: its fill where it's whole, and its lanes, each a row of dots.
		Item {
			id: strip

			x: tile.bar.position === "right" ? parent.width - width - tile.margin : tile.margin
			y: tile.bar.position === "bottom" ? parent.height - height - tile.margin : tile.margin
			width: tile.upright ? tile.across : parent.width - tile.margin * 2
			height: tile.upright ? parent.height - tile.margin * 2 : tile.across
			opacity: tile.bar.autoHide ? 0.45 : 1

			Rectangle {
				anchors.fill: parent
				visible: tile.bar.look === "whole"
				radius: tile.margin > 0 ? Theme.u(2) : 0
				color: Theme.colors.background
				border.width: 1
				border.color: Theme.border
			}

			Repeater {
				model: [
					{ parts: tile.bar.left, at: 0 },
					{ parts: tile.bar.center, at: 0.5 },
					{ parts: tile.bar.right, at: 1 }
				]

				Rectangle {
					id: lane

					required property var modelData
					readonly property real length: Math.max(0, modelData.parts.length * (tile.dot + Theme.u(2)) - Theme.u(2)) + Theme.u(6)
					readonly property real along: Math.max(0, Math.min((tile.upright ? strip.height : strip.width) - length, (tile.upright ? strip.height : strip.width) * modelData.at - length * modelData.at))

					visible: modelData.parts.length > 0
					x: tile.upright ? 0 : along
					y: tile.upright ? along : 0
					width: tile.upright ? strip.width : length
					height: tile.upright ? length : strip.height
					radius: Theme.u(2)
					color: tile.bar.look === "islands" ? Theme.colors.background : "transparent"

					Grid {
						anchors.centerIn: parent
						columns: tile.upright ? 1 : 100
						spacing: Theme.u(2)

						Repeater {
							model: lane.modelData.parts

							Rectangle {
								required property string modelData

								width: tile.bar.look === "capsules" && !tile.upright ? tile.dot * 2 : tile.dot
								height: tile.bar.look === "capsules" && tile.upright ? tile.dot * 2 : tile.dot
								radius: Math.min(width, height) / 2
								color: modelData === "clock" || modelData === "workspaces" ? Theme.colors.accent : Theme.colors.text
								opacity: 0.8
								border.width: tile.bar.look === "capsules" ? Theme.u(1.5) : 0
								border.color: Theme.colors.background
							}
						}
					}
				}
			}
		}

		// The dock.
		Rectangle {
			visible: !!tile.layout.settings.dock.on
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: Theme.u(3)
			width: parent.width * 0.42
			height: Theme.u(9)
			radius: Theme.u(3)
			color: Theme.colors.background
			border.width: 1
			border.color: Theme.border
		}
	}

	Text {
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		anchors.margins: Theme.u(8)
		text: Tr.t(tile.layout.text)
		horizontalAlignment: Text.AlignHCenter
		elide: Text.ElideRight
		color: tile.on ? Theme.colors.accent : Theme.colors.text
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(1)
	}

	MouseArea {
		id: pointer

		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: Layouts.take(tile.layout.name)
	}
}
