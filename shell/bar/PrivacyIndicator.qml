import QtQuick
import qs
import qs.services
import qs.ui

// While an app records from a microphone or has a camera: their icons, in red,
// and the pointer on it says which apps.
Button {
	id: button

	readonly property var microphone: Privacy.microphone
	readonly property var camera: Privacy.camera
	readonly property bool wanted: microphone.length > 0 || camera.length > 0

	height: Theme.u(28)
	implicitWidth: microphone.length > 0 && camera.length > 0 ? Theme.barIcon * 2 + Theme.u(6) + pad * 2 : height
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	icon: microphone.length > 0 ? "mic" : "video"
	ink: Theme.colors.error
	tip: [microphone.length > 0 ? `Microphone: ${microphone.join(", ")}` : "", camera.length > 0 ? `Camera: ${camera.join(", ")}` : ""].filter(part => part !== "").join(" · ")

	// With both, the camera beside the microphone.
	Icon {
		anchors.verticalCenter: parent.verticalCenter
		visible: button.microphone.length > 0 && button.camera.length > 0
		name: "video"
		size: Theme.barIcon
		color: Theme.colors.error
	}

	Component.onCompleted: Privacy.users += 1
	Component.onDestruction: Privacy.users -= 1
}
