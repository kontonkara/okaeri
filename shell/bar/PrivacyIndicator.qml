import QtQuick
import qs
import qs.services
import qs.ui

// While an app records from a microphone or has a camera: their icons, in red,
// and the pointer on it says which apps.
Item {
	id: signs

	readonly property var microphone: Privacy.microphone
	readonly property var camera: Privacy.camera
	readonly property bool wanted: microphone.length > 0 || camera.length > 0

	implicitWidth: grid.implicitWidth
	implicitHeight: grid.implicitHeight
	visible: wanted

	// The tip covers it all, and among the icons it would be one of them.
	Grid {
		id: grid

		columns: Settings.barSide ? 1 : 1000
		padding: Theme.u(6)
		spacing: Theme.u(6)

		Icon {
			visible: signs.microphone.length > 0
			name: "mic"
			size: Theme.barIcon
			color: Theme.colors.error
		}

		Icon {
			visible: signs.camera.length > 0
			name: "video"
			size: Theme.barIcon
			color: Theme.colors.error
		}
	}

	Tip {
		text: [signs.microphone.length > 0 ? `Microphone: ${signs.microphone.join(", ")}` : "", signs.camera.length > 0 ? `Camera: ${signs.camera.join(", ")}` : ""].filter(part => part !== "").join(" · ")
	}

	Component.onCompleted: Privacy.users += 1
	Component.onDestruction: Privacy.users -= 1
}
