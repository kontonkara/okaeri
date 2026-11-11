import QtQuick
import qs
import qs.services
import qs.ui

// The laptop's battery, when there is one: always, on battery or when it's low,
// as Settings.battery.show says, and beside it the percent, the time left or
// nothing. The pointer on it says how it's doing.
Item {
	id: battery

	readonly property var own: Settings.battery
	readonly property int level: Power.charge
	readonly property bool charging: !Power.draining
	readonly property color tint: Power.low ? Theme.colors.error : Theme.colors.text

	readonly property bool wanted: Power.present && (own.show === "always" || (own.show === "battery" && Power.draining) || (own.show === "low" && Power.low))

	property alias leftPadding: row.leftPadding
	property alias rightPadding: row.rightPadding

	implicitWidth: row.implicitWidth
	implicitHeight: row.implicitHeight
	visible: wanted

	// The tip covers it all, and in a row it would be one of the things in it.
	Row {
		id: row

		spacing: Theme.u(6)

		Icon {
			anchors.verticalCenter: parent.verticalCenter
			visible: battery.charging
			name: "bolt"
			size: Theme.u(13)
			color: battery.tint
		}

		Item {
			anchors.verticalCenter: parent.verticalCenter
			width: Theme.u(24)
			height: Theme.u(12)

			Rectangle {
				id: cell

				width: parent.width - Theme.u(3)
				height: parent.height
				radius: Math.min(Theme.u(3), Theme.round(height))
				color: "transparent"
				border.width: Math.max(1, Theme.u(1.5))
				border.color: battery.tint
			}

			Rectangle {
				x: cell.width + Theme.u(1)
				anchors.verticalCenter: parent.verticalCenter
				width: Theme.u(2)
				height: Theme.u(5)
				radius: Math.min(Theme.u(1), Theme.round(height))
				color: battery.tint
			}

			Rectangle {
				readonly property real inset: cell.border.width + Theme.u(1.5)

				x: inset
				y: inset
				width: Math.max(Theme.u(2), (cell.width - inset * 2) * battery.level / 100)
				height: cell.height - inset * 2
				radius: Math.min(Theme.u(1), Theme.round(height))
				color: battery.tint
			}
		}

		Text {
			anchors.verticalCenter: parent.verticalCenter
			visible: battery.own.label !== "none"
			text: battery.own.label === "time" && Power.timeLeft > 0 ? Power.clock(Power.timeLeft) : `${battery.level}%`
			color: battery.tint
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
			font.weight: Theme.fontWeight
			font.features: {
				"tnum": 1
			}
		}
	}

	Tip {
		text: [`${battery.level}%`, Power.batteryLine, Power.othersLine].filter(part => part !== "").join(" · ")
	}
}
