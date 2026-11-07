import QtQuick
import qs
import qs.ui

// A line to pick a number out of `values`, from low to high, by the
// arrows or the wheel: `text`, and `subtext` if it has one. It shows `value`, which
// can be one that's not among them, as a config can say anything, and says
// chosen(value), as Setting does. 0 reads as `none`, and with a `unit` it's not
// seconds but numbers of that.
Item {
	id: choice

	required property string text
	property string subtext
	required property var values
	property real value: 0
	property string none: "Never"
	property string unit
	readonly property real lower: values.filter(other => other < value).pop() ?? -1
	readonly property real higher: values.find(other => other > value) ?? -1

	signal chosen(real value)

	// `steps` on from where it is, as far as there's any to go.
	function step(steps) {
		let next = value;
		for (let done = 0; done < Math.abs(steps); done++) {
			const found = steps > 0 ? values.find(other => other > next) : values.filter(other => other < next).pop();
			next = found ?? next;
		}
		if (next !== value)
			chosen(next);
	}

	width: parent.width
	height: Theme.u(subtext ? 40 : 30)

	MouseArea {
		property int wheel: 0

		anchors.fill: parent
		acceptedButtons: Qt.NoButton
		onWheel: event => {
			// A touchpad comes in small parts of a notch.
			wheel += event.angleDelta.y;
			const steps = Math.trunc(wheel / 120);
			if (steps !== 0) {
				wheel -= steps * 120;
				choice.step(steps);
			}
		}
	}

	Column {
		anchors.left: parent.left
		anchors.right: picker.left
		anchors.rightMargin: Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter

		Text {
			width: parent.width
			text: choice.text
			textFormat: Text.PlainText
			color: Theme.colors.text
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Text {
			width: parent.width
			visible: text !== ""
			text: choice.subtext
			textFormat: Text.PlainText
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	Row {
		id: picker

		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter

		Button {
			height: Theme.u(28)
			flat: true
			enabled: choice.lower >= 0
			icon: "back"
			onClicked: choice.step(-1)
		}

		Text {
			anchors.verticalCenter: parent.verticalCenter
			width: Theme.u(64)
			horizontalAlignment: Text.AlignHCenter
			text: choice.value === 0 ? choice.none : choice.unit ? `${choice.value}${choice.unit}` : choice.value < 60 ? `${choice.value} s` : `${Math.round(choice.value / 60)} min`
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
			font.features: {
				"tnum": 1
			}
		}

		Button {
			height: Theme.u(28)
			flat: true
			enabled: choice.higher >= 0
			icon: "chevron"
			onClicked: choice.step(1)
		}
	}
}
