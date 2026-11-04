import QtQuick
import Quickshell.Services.UPower
import qs
import qs.ui

// The laptop's battery, when there is one.
Row {
	id: battery

	readonly property var device: UPower.displayDevice
	readonly property int level: Math.round(device.percentage * 100)
	readonly property bool charging: device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged || !UPower.onBattery
	readonly property color tint: level <= 15 && !charging ? Theme.colors.error : Theme.colors.text

	visible: device.isLaptopBattery && device.isPresent
	spacing: Theme.u(6)

	Icon {
		anchors.verticalCenter: parent.verticalCenter
		visible: battery.charging
		name: "bolt"
		size: Theme.u(14)
		color: battery.tint
	}

	Item {
		anchors.verticalCenter: parent.verticalCenter
		width: Theme.u(26)
		height: Theme.u(13)

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
		text: `${battery.level}%`
		color: battery.tint
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		font.weight: Theme.fontWeight
		font.features: {
			"tnum": 1
		}
	}
}
