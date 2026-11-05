import QtQuick
import Quickshell.Io
import qs
import qs.ui
// The volume, the brightness, Wi-Fi, Bluetooth, the power profile and keeping
// awake. What's in it is there only while it shows, so what's typed in it goes
// with it.
Panel {
	id: controlCenter

	align: "top-right"
	onShownChanged: Control.open = shown
	// A reload takes it away without closing it, and what's scanning would go
	// on with nobody left to stop it.
	Component.onDestruction: Control.open = false

	Connections {
		target: Control

		function onToggled() {
			controlCenter.toggle();
		}
	}

	IpcHandler {
		target: "control"

		function toggle(): void {
			controlCenter.toggle();
		}
	}

	Loader {
		width: parent.width
		active: controlCenter.visible

		sourceComponent: Column {
			// What's left of the screen for a list, under the bar and with
			// everything else around it.
			readonly property real room: controlCenter.room - levels.height - wifi.foldedHeight - bluetooth.foldedHeight - power.height - awake.foldedHeight - spacing * 4

			spacing: Math.round(Theme.u(10))

			Levels {
				id: levels
			}

			WifiSection {
				id: wifi

				room: parent.room
			}

			BluetoothSection {
				id: bluetooth

				room: parent.room
			}

			PowerSection {
				id: power
			}

			AwakeSection {
				id: awake
			}
		}
	}
}
