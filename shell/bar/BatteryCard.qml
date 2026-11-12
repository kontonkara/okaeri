import QtQuick
import Quickshell.Services.UPower
import qs
import qs.services
import qs.ui

// How the laptop's battery is doing: its charge and how that went over the last
// day, how much power goes in or out, the energy in it and what it can hold, how
// worn it is, and the charge of what else has a battery. The day is asked of
// UPower as this shows, and again every few minutes while it does.
Column {
	id: card

	readonly property var device: Power.battery
	readonly property bool charging: device?.state === UPowerDeviceState.Charging

	// For the panel to go, as the settings come.
	signal closed

	spacing: Theme.u(10)

	Component.onCompleted: Power.lookHistory()

	Timer {
		interval: 300000
		running: true
		repeat: true
		onTriggered: Power.lookHistory()
	}

	component Line: Item {
		property string text
		property string value

		width: parent.width
		height: Theme.u(20)

		Text {
			anchors.left: parent.left
			anchors.leftMargin: Theme.u(4)
			anchors.verticalCenter: parent.verticalCenter
			text: parent.text
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
			font.weight: Theme.fontWeight
		}

		Text {
			anchors.right: parent.right
			anchors.rightMargin: Theme.u(4)
			anchors.verticalCenter: parent.verticalCenter
			text: parent.value
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(1)
			font.features: {
				"tnum": 1
			}
		}
	}

	Column {
		width: parent.width
		spacing: Theme.u(4)

		Line {
			text: `${Power.charge}%`
			value: card.device ? Power.describe(card.device.state, card.charging ? card.device.timeToFull : card.device.timeToEmpty, 0, 0) : ""
		}

		Chart {
			objectName: "batteryChart"
			width: parent.width
			visible: Power.history.length > 1
			values: Power.history
			count: Power.historyHours * 4
			ink: Power.low ? Theme.colors.error : Theme.colors.accent
		}

		Line {
			visible: Power.history.length > 1
			text: ""
			value: "The last day"
		}
	}

	Column {
		width: parent.width
		spacing: Theme.u(4)
		visible: !!card.device

		Line {
			visible: (card.device?.changeRate ?? 0) > 0
			text: card.charging ? "Going in" : "Going out"
			value: `${(card.device?.changeRate ?? 0).toFixed(1)} W`
		}

		Line {
			visible: (card.device?.energyCapacity ?? 0) > 0
			text: "Energy"
			value: `${(card.device?.energy ?? 0).toFixed(1)} of ${(card.device?.energyCapacity ?? 0).toFixed(1)} Wh`
		}

		Line {
			visible: !!card.device?.healthSupported && card.device.healthPercentage > 0
			text: "Health"
			value: `${Math.round(card.device?.healthPercentage ?? 0)}% of what it held new`
		}
	}

	Column {
		width: parent.width
		spacing: Theme.u(4)
		visible: Power.others.length > 0

		Text {
			leftPadding: Theme.u(4)
			text: "Other devices"
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}

		Repeater {
			model: Power.others

			Line {
				required property var modelData

				text: modelData.name
				value: `${modelData.percent}%`
			}
		}
	}

	// When it warns and saves power, and how soon it locks and sleeps on battery.
	Button {
		height: Theme.u(30)
		flat: true
		icon: "gear"
		text: "Battery settings"
		tip: "On the Session page"
		onClicked: {
			card.closed();
			Settings.pageWanted("Session");
		}
	}
}
