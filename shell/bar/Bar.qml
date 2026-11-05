import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.clipboard
import qs.control
import qs.notifications

// The bar of a screen: the workspaces, the clock, and the tray, the bell, the
// clipboard, the battery and the control center.
PanelWindow {
	id: bar

	anchors {
		top: true
		left: true
		right: true
	}
	margins {
		top: Theme.edge
		left: Theme.edge
		right: Theme.edge
	}
	implicitHeight: Theme.barHeight
	color: "transparent"
	WlrLayershell.namespace: "okaeri-bar"

	Rectangle {
		anchors.fill: parent
		radius: Theme.cardRadius
		color: Theme.colors.background
		border.width: 1
		border.color: Theme.border
	}

	SystemClock {
		id: clock

		precision: SystemClock.Minutes
	}

	Workspaces {
		id: workspaces

		anchors.left: parent.left
		anchors.leftMargin: Theme.u(14)
		anchors.verticalCenter: parent.verticalCenter
		output: bar.screen ? bar.screen.name : ""
	}

	TextMetrics {
		id: dated

		font: time.font
		text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
	}

	Text {
		id: time

		// What the two sides leave it.
		readonly property real from: workspaces.x + workspaces.width + Theme.u(12)
		readonly property real to: status.x - Theme.u(12)

		// In the middle, or beside the right side on a narrow screen. Narrower
		// still the date goes, and then the time.
		x: Math.round(Math.max(from, Math.min((parent.width - width) / 2, to - width)))
		anchors.verticalCenter: parent.verticalCenter
		visible: width <= to - from
		text: dated.advanceWidth <= to - from ? dated.text : Qt.formatDateTime(clock.date, "HH:mm")
		color: Theme.colors.text
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		font.weight: Theme.fontWeight
		font.features: {
			"tnum": 1
		}
	}

	Row {
		id: status

		anchors.right: parent.right
		anchors.rightMargin: Theme.u(9)
		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.u(6)

		Tray {
			anchors.verticalCenter: parent.verticalCenter
		}

		NotificationsButton {}

		ClipboardButton {
			anchors.verticalCenter: parent.verticalCenter
		}

		Battery {
			anchors.verticalCenter: parent.verticalCenter
			leftPadding: Theme.u(5)
			rightPadding: Theme.u(5)
		}

		ControlCenterButton {
			anchors.verticalCenter: parent.verticalCenter
		}
	}

	// For tests/measure.sh: when the first frame went out.
	Connections {
		id: firstFrame

		target: time.Window.window

		function onFrameSwapped() {
			console.info("okaeri: first frame", Date.now());
			firstFrame.enabled = false;
		}
	}
}
