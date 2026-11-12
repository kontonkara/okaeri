import QtQuick
import qs
import qs.services
import qs.ui

// While the screen is recorded: for how long so far, and a click stops it.
BarButton {
	readonly property bool wanted: Recorder.recording

	visible: wanted
	icon: "video"
	text: Recorder.clock(Recorder.elapsed)
	tip: "The screen is recorded: a click stops it"
	ink: Theme.colors.error
	onClicked: Recorder.stop()
}
