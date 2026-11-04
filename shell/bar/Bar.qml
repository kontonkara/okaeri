import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// The bar of a screen: the workspaces, the clock, and the tray, the volume,
// the brightness and the battery. The wheel changes the volume and the
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
		anchors.left: parent.left
		anchors.leftMargin: Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter
		output: bar.screen ? bar.screen.name : ""
	}

	Text {
		id: time

		anchors.centerIn: parent
		text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
		color: Theme.colors.text
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		font.weight: Theme.fontWeight
		font.features: {
			"tnum": 1
		}
	}

	Row {
		anchors.right: parent.right
		anchors.rightMargin: Theme.u(10)
		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.u(4)

		Tray {
			anchors.verticalCenter: parent.verticalCenter
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

		Battery {
			anchors.verticalCenter: parent.verticalCenter
			leftPadding: Theme.u(6)
			rightPadding: Theme.u(4)
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
