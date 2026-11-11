import QtQuick
import qs
import qs.services
import qs.ui

// What the machine is busy with, over the last while: the processor and how
// warm it is, the memory and the swap, the network both ways, and how full the
// disk is. It's read for as long as this shows, as for the bar.
Column {
	id: card

	function gib(bytes) {
		return (bytes / 1073741824).toFixed(1);
	}

	spacing: Theme.u(10)

	Component.onCompleted: System.users += 1
	Component.onDestruction: System.users -= 1

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
			text: "Processor"
			value: [System.cpu >= 0 ? `${System.cpu}%` : "", System.temperature >= 0 ? `${System.temperature} °C` : ""].filter(part => part !== "").join(" · ")
		}

		Chart {
			width: parent.width
			values: System.cpus
			ink: System.temperature >= 85 ? Theme.colors.error : Theme.colors.accent
		}
	}

	Column {
		width: parent.width
		spacing: Theme.u(4)

		Line {
			text: "Memory"
			value: [System.memory >= 0 ? `${card.gib(System.memoryUsed)} of ${card.gib(System.memoryTotal)} GiB` : "", System.swap >= 0 ? `swap ${System.swap}%` : ""].filter(part => part !== "").join(" · ")
		}

		Chart {
			width: parent.width
			values: System.memories
		}
	}

	Column {
		width: parent.width
		spacing: Theme.u(4)

		Line {
			text: "Network"
			value: `↓ ${System.rate(System.down)}/s · ↑ ${System.rate(System.up)}/s`
		}

		// As high as the fastest it's been: at least a hundred kilobytes a second.
		Chart {
			width: parent.width
			values: System.downs
			full: Math.max(102400, ...System.downs, ...System.ups)

			Chart {
				anchors.fill: parent
				color: "transparent"
				values: System.ups
				full: parent.full
				ink: Theme.colors.subtext
			}
		}
	}

	Line {
		visible: System.disk >= 0
		text: "Disk"
		value: `${System.disk}% full`
	}
}
