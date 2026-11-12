import QtQuick
import qs
import qs.services
import qs.ui

// The screen recording: while it's recorded, for how long so far, and a click
// stops it; in the accent while a part of the screen is being picked; and with
// Settings.recording.show "always" there before, for a click to start one. The
// pointer on it says what it takes in, with which sound, and where it goes.
BarButton {
	readonly property bool wanted: Recorder.recording || Recorder.choosing || (Settings.recording.show === "always" && Recorder.available)

	visible: wanted
	icon: "video"
	text: Recorder.recording ? Recorder.clock(Recorder.elapsed) : ""
	tip: Recorder.recording ? `${Recorder.about} · a click stops it` : Recorder.choosing ? "Pick a part of the screen" : `${Recorder.told(Settings.recording.area === "region" && Recorder.picks ? "" : "The screen", Settings.recording.audio, Recorder.folder)} · a click starts it`
	ink: Recorder.recording ? Theme.colors.error : Recorder.choosing ? Theme.colors.accent : Theme.colors.subtext
	onClicked: Recorder.toggle()
}
