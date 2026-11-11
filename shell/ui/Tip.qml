import QtQuick
import Quickshell
import qs

// What `text` says of what it's in, under it once the pointer stays on that a
// moment, with Settings.bar.tips, until it's pressed. A window that has `tipsFrom`
// says how far down its tips go: the bar's go under all of it, or over it with
// `tipsAbove`, for a bar at the bottom. It's a popup, a
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
			readonly property bool above: owner?.tipsAbove ?? false

			anchor.window: owner
			anchor.rect: above ? Qt.rect(at.x, -Theme.u(6), tip.width, 1) : Qt.rect(at.x, 0, tip.width, from)
			anchor.edges: above ? Edges.Top : Edges.Bottom
			anchor.gravity: above ? Edges.Top : Edges.Bottom
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
