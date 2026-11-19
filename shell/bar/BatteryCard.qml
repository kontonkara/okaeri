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
	// What else has a battery: a mouse, a headset, and a phone through KDE Connect.
	readonly property var others: Power.others.concat(Phone.devices.filter(one => one.charge >= 0).map(one => ({ name: one.name, percent: one.charge })))

	// For the panel to go, as the settings come.
	signal closed

	spacing: Theme.u(10)

	Component.onCompleted: {
		Power.lookHistory();
		Power.lookLimit();
	}

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
			text: card.charging ? Tr.t("Going in") : Tr.t("Going out")
			value: `${(card.device?.changeRate ?? 0).toFixed(1)} W`
		}

		Line {
			visible: (card.device?.energyCapacity ?? 0) > 0
			text: Tr.t("Energy")
			value: `${(card.device?.energy ?? 0).toFixed(1)} of ${(card.device?.energyCapacity ?? 0).toFixed(1)} Wh`
		}

		Line {
			visible: !!card.device?.healthSupported && card.device.healthPercentage > 0
			text: Tr.t("Health")
			value: `${Math.round(card.device?.healthPercentage ?? 0)}% of what it held new`
		}
	}

	Column {
		width: parent.width
		spacing: Theme.u(4)
		visible: card.others.length > 0

		Text {
			leftPadding: Theme.u(4)
			text: Tr.t("Other devices")
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}

		Repeater {
			model: card.others

			Line {
				required property var modelData

				text: modelData.name
				value: `${modelData.percent}%`
			}
		}
	}

	// Charging stopped short of full, where the battery can: easier on it, for a
	// machine that's mostly on the charger.
	Item {
		width: parent.width
		height: Theme.u(36)
		visible: Power.limitable

		Column {
			anchors.left: parent.left
			anchors.leftMargin: Theme.u(4)
			anchors.right: limit.left
			anchors.verticalCenter: parent.verticalCenter

			Text {
				width: parent.width
				text: Tr.f("Charge to %1% only", Power.limitTo)
				color: Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}

			Text {
				width: parent.width
				text: Tr.f("And again from %1%, as UPower has it", Power.limitFrom)
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}
		}

		Toggle {
			id: limit

			objectName: "limit"
			anchors.right: parent.right
			anchors.rightMargin: Theme.u(4)
			anchors.verticalCenter: parent.verticalCenter
			checked: Power.limited
			onToggled: wanted => Power.setLimit(wanted)
		}
	}

	// When it warns and saves power, and how soon it locks and sleeps on battery.
	Button {
		height: Theme.u(30)
		flat: true
		icon: "gear"
		text: Tr.t("Battery settings")
		tip: Tr.t("On the Session page")
		onClicked: {
			card.closed();
			Settings.pageWanted("Session");
		}
	}
}
