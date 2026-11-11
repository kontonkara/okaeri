import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The time, and the date beside it, as Settings.clock has them, in `room` pixels:
// with less the date goes, and then the time, and the weather after it if
// Settings.weather.bar says so. The pointer on it says the whole date, and a click
// shows the month, under the weather if that's on and the time in other places.
Text {
	id: time

	property real room: Infinity
	readonly property var own: Settings.clock
	readonly property string timeFormat: (own.hours12 ? "h:mm" : "HH:mm") + (own.seconds ? ":ss" : "") + (own.hours12 ? " AP" : "")
	readonly property var formats: own.date === "none" || !own.dateFormat ? [timeFormat] : own.date === "after" ? [timeFormat, own.dateFormat] : [own.dateFormat, timeFormat]
	readonly property string outside: Weather.on && Settings.weather.bar && Weather.current ? `  ${Weather.current.temperature}°` : ""

	visible: width <= room
	text: (dated.advanceWidth <= room ? dated.text : Qt.formatDateTime(clock.date, timeFormat)) + outside
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

	MouseArea {
		id: pointer

		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: {
			month.middle = Panels.middleOf(time);
			month.toggle();
		}
	}

	Tip {
		listens: false
		hovered: pointer.containsMouse
		pressed: pointer.pressed
		text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
	}

	Panel {
		id: month

		align: "top"
		panelWidth: Theme.u(320)

		Loader {
			width: parent.width
			active: month.visible

			sourceComponent: Column {
				width: parent ? parent.width : 0
				spacing: Theme.u(10)

				WeatherNow {
					width: parent.width
					visible: Weather.on
				}

				Zones {
					width: parent.width
				}

				Calendar {
					width: parent.width
					today: clock.date
				}
			}
		}
	}
}
