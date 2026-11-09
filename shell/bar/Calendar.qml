import QtQuick
import qs
import qs.ui

// A month, today in it marked: the arrows and the wheel go to the months around
// it, and its name back to this one. Weeks start as Settings.clock.weekStart
// says, the locale's way by default, with their numbers if
// Settings.clock.weekNumbers says so.
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

	function turn(months) {
		const to = new Date(year, month + months, 1);
		year = to.getFullYear();
		month = to.getMonth();
	}

	function back() {
		year = today.getFullYear();
		month = today.getMonth();
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
				}
			}
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
