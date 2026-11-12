import QtQuick
import qs
import qs.services
import qs.ui

// A month, today in it marked: the arrows and the wheel go to the months around
// it, and its name back to this one. By the keys that's Left and Right, or Page
// Up and Down, and Home. Weeks start as Settings.clock.weekStart
// says, the locale's way by default, with their numbers if
// Settings.clock.weekNumbers says so. With calendars to read, as Events has
// them, a dot is under each day with something on it, and under the month is
// what's on the day picked: today, or one clicked.
Column {
	id: calendar

	required property date today
	// The month that shows: its year, and the month from 0.
	property int year: today.getFullYear()
	property int month: today.getMonth()
	readonly property int firstDay: {
		const start = Settings.clock.weekStart;
		// Qt's days run 1 for Monday to 7 for Sunday; JavaScript's from 0 for Sunday.
		return start === "monday" ? 1 : start === "sunday" ? 0 : Qt.locale().firstDayOfWeek % 7;
	}
	// The six weeks that show, from the first that has a day of the month.
	readonly property var days: {
		const first = new Date(year, month, 1);
		const back = (first.getDay() - firstDay + 7) % 7;
		return Array.from({ length: 42 }, (_, index) => new Date(year, month, 1 - back + index));
	}
	readonly property real cell: Theme.u(36)
	// A day clicked, or null for today.
	property var chosen: null
	readonly property date picked: chosen ?? today
	// The days with something on them, of the months around this one too, and
	// what's on the day picked.
	readonly property var marks: Events.on ? Events.marked(new Date(year, month - 1, 1), new Date(year, month + 2, 1)) : ({})
	readonly property var happening: Events.on ? Events.happening(picked) : []
	// As many lines of that as show: past them the last one says how many more.
	readonly property int lines: 6

	function turn(months) {
		const to = new Date(year, month + months, 1);
		year = to.getFullYear();
		month = to.getMonth();
	}

	function back() {
		year = today.getFullYear();
		month = today.getMonth();
		chosen = null;
	}

	function pick(day) {
		chosen = same(day, today) ? null : day;
	}

	// When something on the day picked is, at the start of its line: the time it
	// starts, or ends if it began the day before, or all day.
	function timeOf(one) {
		const format = Settings.clock.hours12 ? "h:mm AP" : "HH:mm";
		const from = new Date(picked.getFullYear(), picked.getMonth(), picked.getDate());
		const to = new Date(picked.getFullYear(), picked.getMonth(), picked.getDate() + 1);
		if (one.allDay || (one.start < from && one.end >= to))
			return "All day";
		return one.start < from ? `Until ${Qt.formatDateTime(one.end, format)}` : Qt.formatDateTime(one.start, format);
	}

	function same(a, b) {
		return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
	}

	// ISO 8601: the week with the year's first Thursday is its first.
	function week(day) {
		const thursday = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 3 - (day.getDay() + 6) % 7);
		const first = new Date(thursday.getFullYear(), 0, 4);
		return 1 + Math.round(((thursday - first) / 86400000 - 3 + (first.getDay() + 6) % 7) / 7);
	}

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp)
			turn(-1);
		else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown)
			turn(1);
		else if (event.key === Qt.Key_Home)
			back();
		else
			return;
		event.accepted = true;
	}

	spacing: Theme.u(6)

	Item {
		width: parent.width
		height: Theme.u(34)

		Button {
			id: earlier

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(30)
			flat: true
			icon: "back"
			onClicked: calendar.turn(-1)
		}

		Button {
			anchors.centerIn: parent
			height: Theme.u(30)
			flat: true
			text: Qt.locale().standaloneMonthName(calendar.month, Locale.LongFormat) + (calendar.year === calendar.today.getFullYear() ? "" : ` ${calendar.year}`)
			tip: "Back to today"
			onClicked: calendar.back()
		}

		Button {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(30)
			flat: true
			icon: "chevron"
			onClicked: calendar.turn(1)
		}
	}

	Row {
		anchors.horizontalCenter: parent.horizontalCenter

		// The weeks' numbers, down the side.
		Column {
			visible: Settings.clock.weekNumbers

			Item {
				width: calendar.cell
				height: calendar.cell * 0.8
			}

			Repeater {
				model: 6

				Text {
					required property int index

					width: calendar.cell
					height: calendar.cell
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
					text: calendar.week(calendar.days[index * 7 + 3])
					color: Theme.colors.subtext
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(3)
					font.features: {
						"tnum": 1
					}
				}
			}
		}

		Grid {
			columns: 7

			Repeater {
				model: 7

				Text {
					required property int index

					width: calendar.cell
					height: calendar.cell * 0.8
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
					// Qt counts from Sunday as 0 here too.
					text: Qt.locale().dayName((calendar.firstDay + index) % 7, Locale.ShortFormat)
					color: Theme.colors.subtext
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(3)
				}
			}

			Repeater {
				model: calendar.days

				Item {
					required property var modelData
					readonly property bool isToday: calendar.same(modelData, calendar.today)
					readonly property bool inMonth: modelData.getMonth() === calendar.month
					readonly property bool isPicked: calendar.chosen !== null && calendar.same(modelData, calendar.chosen)

					width: calendar.cell
					height: calendar.cell

					Rectangle {
						anchors.centerIn: parent
						width: calendar.cell - Theme.u(6)
						height: width
						radius: Theme.round(height)
						visible: parent.isToday
						color: Theme.colors.accent
					}

					// The day picked, ringed, and one under the pointer that can be.
					Rectangle {
						anchors.centerIn: parent
						width: calendar.cell - Theme.u(6)
						height: width
						radius: Theme.round(height)
						visible: !parent.isToday && (parent.isPicked || pointer.containsMouse)
						color: parent.isPicked ? "transparent" : Theme.hover
						border.width: parent.isPicked ? Math.max(1, Math.round(Theme.u(1.5))) : 0
						border.color: Theme.colors.accent
					}

					Text {
						anchors.centerIn: parent
						text: parent.modelData.getDate()
						color: parent.isToday ? Theme.colors.background : parent.inMonth ? Theme.colors.text : Qt.alpha(Theme.colors.text, 0.3)
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
						font.weight: parent.isToday ? Theme.fontWeight : Font.Normal
						font.features: {
							"tnum": 1
						}
					}

					// Something on it, from a calendar.
					Rectangle {
						anchors.horizontalCenter: parent.horizontalCenter
						anchors.bottom: parent.bottom
						anchors.bottomMargin: Theme.u(5)
						width: 2 * Math.max(1, Math.round(Theme.u(2)))
						height: width
						radius: width / 2
						visible: !!calendar.marks[Events.key(parent.modelData)]
						color: parent.isToday ? Theme.colors.background : Theme.colors.accent
						opacity: parent.inMonth ? 1 : 0.4
					}

					// Only with calendars is there anything to pick a day for.
					MouseArea {
						id: pointer

						anchors.fill: parent
						enabled: Events.on
						hoverEnabled: true
						cursorShape: Events.on ? Qt.PointingHandCursor : Qt.ArrowCursor
						onClicked: calendar.pick(parent.modelData)
					}
				}
			}
		}
	}

	// What's on the day picked, with calendars to tell it.
	Column {
		width: parent.width
		visible: Events.on
		spacing: Theme.u(2)

		Rectangle {
			width: parent.width
			height: 1
			color: Theme.border
		}

		Text {
			x: Theme.u(8)
			width: parent.width - Theme.u(16)
			topPadding: Theme.u(6)
			bottomPadding: Theme.u(2)
			text: calendar.same(calendar.picked, calendar.today) ? "Today" : Qt.formatDate(calendar.picked, calendar.picked.getFullYear() === calendar.today.getFullYear() ? "dddd, d MMMM" : "dddd, d MMMM yyyy")
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}

		Repeater {
			model: calendar.happening.length > calendar.lines ? calendar.happening.slice(0, calendar.lines - 1) : calendar.happening

			Item {
				required property var modelData

				width: parent.width
				height: Theme.u(24)

				Text {
					id: starts

					anchors.left: parent.left
					anchors.leftMargin: Theme.u(8)
					anchors.verticalCenter: parent.verticalCenter
					width: Theme.u(Settings.clock.hours12 ? 88 : 72)
					text: calendar.timeOf(parent.modelData)
					color: Theme.colors.subtext
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(2)
					font.features: {
						"tnum": 1
					}
				}

				Text {
					anchors.left: starts.right
					anchors.leftMargin: Theme.u(8)
					anchors.right: parent.right
					anchors.rightMargin: Theme.u(8)
					anchors.verticalCenter: parent.verticalCenter
					text: parent.modelData.summary
					textFormat: Text.PlainText
					color: Theme.colors.text
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
				}
			}
		}

		Text {
			x: Theme.u(8)
			width: parent.width - Theme.u(16)
			height: Theme.u(24)
			visible: text !== ""
			verticalAlignment: Text.AlignVCenter
			text: calendar.happening.length === 0 ? "Nothing that day" : calendar.happening.length > calendar.lines ? `And ${calendar.happening.length - calendar.lines + 1} more` : ""
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}

		// A calendar that hasn't come.
		Text {
			x: Theme.u(8)
			width: parent.width - Theme.u(16)
			visible: Events.problem !== ""
			text: `A calendar: ${Events.problem}`
			color: Theme.colors.error
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	// The wheel goes along the months.
	WheelHandler {
		acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
		onWheel: event => {
			wheeled += event.angleDelta.y;
			const steps = Math.trunc(wheeled / 120);
			if (steps !== 0) {
				wheeled -= steps * 120;
				calendar.turn(-steps);
			}
		}

		property int wheeled: 0
	}
}
