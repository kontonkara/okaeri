import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// The bar of a screen: the workspaces, the clock, and the tray, the battery,
// the volume and the brightness. The wheel changes the volume and the
// brightness, a click mutes.
PanelWindow {
	id: bar

	anchors {
		top: true
		left: true
		right: true
	}
	implicitHeight: Theme.barHeight
	color: Theme.colors.background
	WlrLayershell.namespace: "okaeri-bar"

	SystemClock {
		id: clock

		precision: SystemClock.Minutes
	}

	Workspaces {
		id: workspaces

		anchors.left: parent.left
		anchors.leftMargin: Theme.u(12)
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
		anchors.rightMargin: Theme.u(10)
		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.u(4)

		Tray {
			anchors.verticalCenter: parent.verticalCenter
		}

		Battery {
			anchors.verticalCenter: parent.verticalCenter
			leftPadding: Theme.u(6)
			rightPadding: Theme.u(4)
		}

		Button {
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(28)
			flat: true
			activeFocusOnTab: false
			icon: Audio.muted ? "volumeOff" : "volume"
			text: `${Math.round(Audio.volume * 100)}%`
			ink: Audio.muted ? Theme.colors.subtext : Theme.colors.text
			onClicked: Audio.toggleMute()
			onScrolled: steps => Audio.change(steps * 0.05)
		}

		Button {
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(28)
			visible: Brightness.available
			flat: true
			activeFocusOnTab: false
			icon: "sun"
			text: `${Math.round(Brightness.level * 100)}%`
			onScrolled: steps => Brightness.change(steps * 0.05)
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
