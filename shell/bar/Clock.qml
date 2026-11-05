import QtQuick
import Quickshell
import qs

// The date and the time, in `room` pixels: with less the date goes, and then
// the time.
Text {
	id: time

	property real room: Infinity

	visible: width <= room
	text: dated.advanceWidth <= room ? dated.text : Qt.formatDateTime(clock.date, "HH:mm")
	color: Theme.colors.text
	font.family: Theme.font
	font.pixelSize: Theme.fontSize
	font.weight: Theme.fontWeight
	font.features: {
		"tnum": 1
	}

	SystemClock {
		id: clock

		precision: SystemClock.Minutes
	}

	TextMetrics {
		id: dated

		font: time.font
		text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
	}
}
