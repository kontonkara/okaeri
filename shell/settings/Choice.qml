import QtQuick
import qs
import qs.ui

// A line to pick a number out of `values`, from low to high, by the
// arrows or the wheel: `text`, and `subtext` if it has one. It shows `value`, which
// can be one that's not among them, as a config can say anything, and says
// chosen(value), as Setting does. 0 reads as `none`, the last of them as `most`
// if that's given, and with a `unit` it's not seconds but numbers of that. With
// an arrow in focus, Left and Right step too, and Home and End go to the lowest
// and the highest.
Item {
	id: choice

	required property string text
	// What it sets, "section.key" or "theme.key", for its mark; and more words
	// the search finds it by.
	property string holds
	property string words
	property string subtext
	required property var values
	property real value: 0
	property string none: "Never"
	property string most
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
		go(next);
	}

	// To `next`, one of `values`. An arrow in focus that would go out at an end
	// hands the focus to the other first, so the keys still work.
	function go(next) {
		if (next === undefined || next === value)
			return;
		if (next <= values[0] && backward.activeFocus)
			forward.forceActiveFocus();
		else if (next >= values[values.length - 1] && forward.activeFocus)
			backward.forceActiveFocus();
		chosen(next);
	}

	width: parent.width
	height: Theme.u(subtext ? 40 : 30)

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Left)
			step(-1);
		else if (event.key === Qt.Key_Right)
			step(1);
		else if (event.key === Qt.Key_Home)
			go(values[0]);
		else if (event.key === Qt.Key_End)
			go(values[values.length - 1]);
		else
			return;
		event.accepted = true;
	}

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

		// On a page that scrolls, the wheel over these is still the line's: Glide
		// lets it through.
		readonly property bool takesWheel: true

		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter

		Button {
			id: backward

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
			text: choice.value === 0 ? choice.none : choice.most && choice.value === choice.values[choice.values.length - 1] ? choice.most : choice.unit ? `${choice.value}${choice.unit}` : choice.value < 60 ? `${choice.value} s` : `${Math.round(choice.value / 60)} min`
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
			font.features: {
				"tnum": 1
			}
		}

		Button {
			id: forward

			height: Theme.u(28)
			flat: true
			enabled: choice.higher >= 0
			icon: "chevron"
			onClicked: choice.step(1)
		}
	}

	Mark {
		holds: choice.holds
	}
}
