import QtQuick
import qs
import qs.control
import qs.services
import qs.ui

// While an app records from a microphone or has a camera: their icons, in red,
// and the pointer on it says which apps. A click mutes the microphone, or has it
// back, the wheel turns it, and the middle button opens the control center at it.
Item {
	id: signs

	readonly property var microphone: Privacy.microphone
	readonly property var camera: Privacy.camera
	readonly property bool wanted: microphone.length > 0 || camera.length > 0
	readonly property bool listened: microphone.length > 0

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
			visible: signs.listened
			name: Audio.micMuted ? "micOff" : "mic"
			size: Theme.barIcon
			color: Audio.micMuted ? Theme.colors.subtext : Theme.colors.error
		}

		Icon {
			visible: signs.camera.length > 0
			name: "video"
			size: Theme.barIcon
			color: Theme.colors.error
		}
	}

	MouseArea {
		id: pointer

		property int wheel: 0

		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.MiddleButton
		cursorShape: Qt.PointingHandCursor
		onClicked: event => {
			if (event.button === Qt.MiddleButton) {
				Control.unfolded = "mic";
				Control.toggle();
			} else if (signs.listened) {
				Audio.toggleMicMute();
			}
		}
		onWheel: event => {
			// A touchpad comes in small parts of a notch.
			wheel += event.angleDelta.y;
			const steps = Math.trunc(wheel / 120);
			if (steps !== 0) {
				wheel -= steps * 120;
				Audio.changeMic(steps * Settings.audio.step / 100);
			}
		}
	}

	Tip {
		text: [signs.listened ? `Microphone${Audio.micMuted ? ", muted" : ""}: ${signs.microphone.join(", ")}` : "", signs.camera.length > 0 ? `Camera: ${signs.camera.join(", ")}` : "", signs.listened ? (Audio.micMuted ? "A click has it back" : "A click mutes it") : ""].filter(part => part !== "").join(" · ")
		listens: false
		hovered: pointer.containsMouse
		pressed: pointer.pressed
	}

	Component.onCompleted: Privacy.users += 1
	Component.onDestruction: Privacy.users -= 1
}
