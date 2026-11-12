import QtQuick
import Quickshell.Widgets
import qs
import qs.ui

// A line to pick one of `options`, { value, text }, by the arrows or the wheel:
// `text`, and `subtext` and `image` if it has them. It shows `value`, and says
// chosen(value), as Choice does for numbers. With an arrow in focus, Left and
// Right step too, and Home and End go to the first and the last.
Item {
	id: pick

	required property string text
	// What it sets, "section.key" or "theme.key", for its mark; and more words
	// the search finds it by.
	property string holds
	property string words
	property string subtext
	property string image
	required property var options
	property var value
	// How wide what it shows gets.
	property real valueWidth: Theme.u(100)
	readonly property int at: options.findIndex(option => option.value === value)

	signal chosen(var value)

	function step(by) {
		go(at + by);
	}

	// To the option at `index`, where there's one. An arrow in focus that would
	// go out at an end hands the focus to the other first, so the keys still work.
	function go(index) {
		const next = options[index];
		if (!next || index === at)
			return;
		if (index === 0 && backward.activeFocus)
			forward.forceActiveFocus();
		else if (index === options.length - 1 && forward.activeFocus)
			backward.forceActiveFocus();
		chosen(next.value);
	}

	width: parent.width
	height: Theme.u(subtext ? 40 : 30)

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Left)
			step(-1);
		else if (event.key === Qt.Key_Right)
			step(1);
		else if (event.key === Qt.Key_Home)
			go(0);
		else if (event.key === Qt.Key_End)
			go(options.length - 1);
		else
			return;
		event.accepted = true;
	}

	// Under the arrows, which take a click and let the wheel through.
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
				pick.step(steps);
			}
		}
	}

	IconImage {
		id: picture

		anchors.verticalCenter: parent.verticalCenter
		visible: pick.image !== ""
		source: pick.image
		implicitSize: Theme.u(20)
	}

	Column {
		anchors.left: picture.visible ? picture.right : parent.left
		anchors.leftMargin: picture.visible ? Theme.u(10) : 0
		anchors.right: picker.left
		anchors.rightMargin: Theme.u(12)
		anchors.verticalCenter: parent.verticalCenter

		Text {
			width: parent.width
			text: pick.text
			textFormat: Text.PlainText
			color: Theme.colors.text
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Text {
			width: parent.width
			visible: text !== ""
			text: pick.subtext
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
			enabled: pick.at > 0
			icon: "back"
			onClicked: pick.step(-1)
		}

		Text {
			anchors.verticalCenter: parent.verticalCenter
			width: pick.valueWidth
			horizontalAlignment: Text.AlignHCenter
			text: pick.options[pick.at]?.text ?? ""
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Button {
			id: forward

			height: Theme.u(28)
			flat: true
			enabled: pick.at < pick.options.length - 1
			icon: "chevron"
			onClicked: pick.step(1)
		}
	}

	Mark {
		holds: pick.holds
	}
}
