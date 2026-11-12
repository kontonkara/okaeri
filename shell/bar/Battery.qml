import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The laptop's battery, when there is one: always, on battery or when it's low,
// as Settings.battery.show says, and beside it the percent, the time left or
// nothing, under it on a bar at a side. The pointer on it says how it's doing,
// and a click shows it in full, with how the charge went over the last day.
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

	// On this bar's screen, not the one in focus: a click can come from another.
	function flip() {
		card.middle = Panels.middleOf(battery);
		if (card.shown)
			card.hide();
		else
			card.show(battery.QsWindow.window.screen);
	}

	// `okaeri battery toggle`, for a key.
	Connections {
		target: Panels

		function onPartWanted(name, screen) {
			if (name !== "battery" || !battery.visible || Panels.answered || (screen !== "" && screen !== battery.QsWindow.window?.screen?.name))
				return;
			Panels.answered = true;
			battery.flip();
		}
	}

	// As tall as a button of the bar, under it and the pointer.
	Rectangle {
		id: back

		anchors.centerIn: parent
		width: parent.width + (Settings.barSide ? Theme.u(4) : 0)
		height: Settings.barSide ? parent.height + Theme.u(10) : Theme.u(28)
		radius: Theme.round(Math.min(width, height))
		color: pointer.pressed ? Qt.alpha(Theme.colors.text, 0.16) : pointer.containsMouse ? Qt.alpha(Theme.colors.text, 0.08) : "transparent"
	}

	// The tip covers it all, and in a row it would be one of the things in it.
	Grid {
		id: row

		columns: Settings.barSide ? 1 : 1000
		horizontalItemAlignment: Grid.AlignHCenter
		verticalItemAlignment: Grid.AlignVCenter
		spacing: Theme.u(Settings.barSide ? 3 : 6)

		Icon {
			visible: battery.charging
			name: "bolt"
			size: Theme.u(13)
			color: battery.tint
		}

		Item {
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
			visible: battery.own.label !== "none"
			// An even width under the cell, which is one: on half a pixel the letters
			// would smear.
			width: Settings.barSide ? 2 * Math.ceil(implicitWidth / 2) : implicitWidth
			horizontalAlignment: Text.AlignHCenter
			text: battery.own.label === "time" && Power.timeLeft > 0 ? Power.clock(Power.timeLeft) : Settings.barSide ? `${battery.level}` : `${battery.level}%`
			color: battery.tint
			font.family: Theme.font
			font.pixelSize: Settings.barSide ? Theme.fontSize - Theme.u(4) : Theme.fontSize
			font.weight: Theme.fontWeight
			font.features: {
				"tnum": 1
			}
		}
	}

	MouseArea {
		id: pointer

		anchors.fill: back
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: battery.flip()
	}

	Tip {
		listens: false
		hovered: pointer.containsMouse
		pressed: pointer.pressed
		text: [`${battery.level}%`, Power.batteryLine, Power.othersLine].filter(part => part !== "").join(" · ")
	}

	Panel {
		id: card

		align: "top"
		panelWidth: Theme.u(320)

		Loader {
			width: parent.width
			active: card.visible

			sourceComponent: BatteryCard {
				onClosed: card.hide()
			}
		}
	}
}
