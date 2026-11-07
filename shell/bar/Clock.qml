import QtQuick
import Quickshell
import qs

// The time, and the date beside it, as Settings.clock has them, in `room` pixels:
// with less the date goes, and then the time.
Text {
	id: time

	property real room: Infinity
	readonly property var own: Settings.clock
	readonly property string timeFormat: (own.hours12 ? "h:mm" : "HH:mm") + (own.seconds ? ":ss" : "") + (own.hours12 ? " AP" : "")
	readonly property var formats: own.date === "none" || !own.dateFormat ? [timeFormat] : own.date === "after" ? [timeFormat, own.dateFormat] : [own.dateFormat, timeFormat]

	visible: width <= room
	text: dated.advanceWidth <= room ? dated.text : Qt.formatDateTime(clock.date, timeFormat)
	color: Theme.colors.text
	font.family: Theme.font
	font.pixelSize: Theme.fontSize
	font.weight: Theme.fontWeight
	font.features: {
		"tnum": 1
	}

	SystemClock {
		id: clock

		precision: time.own.seconds ? SystemClock.Seconds : SystemClock.Minutes
	}

	TextMetrics {
		id: dated

		font: time.font
		text: time.formats.map(format => Qt.formatDateTime(clock.date, format)).join("  ")
	}
}
