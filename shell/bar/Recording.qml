import QtQuick
import qs
import qs.services
import qs.ui

// While the screen is recorded: for how long so far, and a click stops it.
Button {
	readonly property bool wanted: Recorder.recording

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	icon: "video"
	text: Recorder.clock(Recorder.elapsed)
	tip: "The screen is recorded: a click stops it"
	ink: Theme.colors.error
	onClicked: Recorder.stop()
}
