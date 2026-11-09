import QtQuick
import qs
import qs.services
import qs.ui

// The weather in the month's card: now, where, and the days to come, each with
// its high and low. While it's waiting, or with trouble, it says so.
Column {
	id: now

	readonly property var current: Weather.current
	readonly property var coming: Weather.days.slice(1, 4)

	spacing: Theme.u(8)

	Item {
		width: parent.width
		height: Theme.u(44)

		Icon {
			id: sky

			anchors.left: parent.left
			anchors.leftMargin: Theme.u(8)
			anchors.verticalCenter: parent.verticalCenter
			visible: !!now.current
			name: now.current ? Weather.icon(now.current.code, now.current.day) : "cloud"
			size: Theme.u(28)
		}

		Text {
			id: degrees

			anchors.left: sky.right
			anchors.leftMargin: Theme.u(10)
			anchors.verticalCenter: parent.verticalCenter
			visible: !!now.current
			text: now.current ? `${now.current.temperature}°` : ""
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize + Theme.u(8)
			font.weight: Theme.fontWeight
			font.features: {
				"tnum": 1
			}
		}

		Column {
			anchors.left: now.current ? degrees.right : parent.left
			anchors.leftMargin: Theme.u(12)
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter

			Text {
				width: parent.width
				text: now.current ? [Weather.about(now.current.code), Weather.days[0] ? `${Weather.days[0].high}° / ${Weather.days[0].low}°` : ""].filter(part => part !== "").join(" · ") : Weather.trouble ? `The weather: ${Weather.trouble}` : "The weather is on its way"
				color: Weather.trouble && !now.current ? Theme.colors.error : Theme.colors.text
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}

			Text {
				width: parent.width
				text: Weather.own.place
				textFormat: Text.PlainText
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}
		}
	}

	Row {
		width: parent.width
		visible: now.coming.length > 0

		Repeater {
			model: now.coming

			Column {
				required property var modelData

				width: parent.width / Math.max(1, now.coming.length)
				spacing: Theme.u(2)

				Text {
					anchors.horizontalCenter: parent.horizontalCenter
					text: Qt.locale().dayName(modelData.date.getDay(), Locale.ShortFormat)
					color: Theme.colors.subtext
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(2)
				}

				Icon {
					anchors.horizontalCenter: parent.horizontalCenter
					name: Weather.icon(modelData.code, true)
					size: Theme.u(20)
				}

				Text {
					anchors.horizontalCenter: parent.horizontalCenter
					text: `${modelData.high}° / ${modelData.low}°`
					color: Theme.colors.text
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(2)
					font.features: {
						"tnum": 1
					}
				}
			}
		}
	}

	Rectangle {
		width: parent.width
		height: 1
		color: Theme.border
	}
}
