import QtQuick
import Quickshell
import qs

// What `text` says of what it's in, under it once the pointer stays on that a
// moment, with Settings.bar.tips, until it's pressed. A window that has `tipsFrom`
// says how far from its edge its tips go, and with `tipsAt` on which side of it:
// the bar's go "below" all of it, "above" it at the bottom of the screen, and to
// the "right" or the "left" of one at a side. It's a popup, a
// window of its own: made as it shows and gone as it hides, as a window costs
// memory while it's there.
//
// What has a MouseArea of its own says `hovered` and `pressed`, with `listens` off:
// a handler here, over it, would take the pointer from it.
Item {
	id: tip

	property string text
	property bool listens: true
	property bool hovered: hover.hovered
	property bool pressed: false
	readonly property bool wanted: Settings.bar.tips && text !== "" && hovered
	property bool due: false

	anchors.fill: parent

	onPressedChanged: {
		if (pressed) {
			delay.stop();
			due = false;
		}
	}

	onWantedChanged: {
		due = false;
		if (wanted)
			delay.restart();
		else
			delay.stop();
	}

	HoverHandler {
		id: hover

		enabled: tip.listens
	}

	Timer {
		id: delay

		interval: 600
		onTriggered: tip.due = true
	}

	LazyLoader {
		active: tip.due

		PopupWindow {
			readonly property var owner: tip.QsWindow.window
			readonly property point at: tip.mapToItem(null, 0, 0)
			readonly property real from: owner?.tipsFrom ?? at.y + tip.height + Theme.u(6)
			readonly property string side: owner?.tipsAt ?? "below"

			anchor.window: owner
			anchor.rect: side === "above" ? Qt.rect(at.x, -Theme.u(6), tip.width, 1)
				: side === "right" ? Qt.rect(0, at.y, from, tip.height)
				: side === "left" ? Qt.rect(-Theme.u(6), at.y, 1, tip.height)
				: Qt.rect(at.x, 0, tip.width, from)
			anchor.edges: side === "above" ? Edges.Top : side === "right" ? Edges.Right : side === "left" ? Edges.Left : Edges.Bottom
			anchor.gravity: side === "above" ? Edges.Top : side === "right" ? Edges.Right : side === "left" ? Edges.Left : Edges.Bottom
			implicitWidth: Math.ceil(label.width + Theme.u(20))
			implicitHeight: Math.ceil(label.height + Theme.u(12))
			visible: true
			color: "transparent"

			Rectangle {
				anchors.fill: parent
				radius: Math.min(Theme.cardRadius, Theme.round(height))
				color: Theme.colors.background
				border.width: 1
				border.color: Theme.border

				Text {
					id: label

					anchors.centerIn: parent
					width: Math.min(implicitWidth, Theme.u(360))
					text: tip.text
					textFormat: Text.PlainText
					wrapMode: Text.Wrap
					color: Theme.colors.text
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(1)
				}
			}
		}
	}
}
