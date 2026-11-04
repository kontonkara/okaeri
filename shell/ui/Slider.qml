import QtQuick
import qs

// A level from 0 to 1. It shows `value` and says moved(wanted), by the
// pointer, the wheel and the arrow keys; `interactive: false` for a gauge.
Item {
	id: slider

	property real value: 0
	property bool interactive: true
	property real step: 0.05

	signal moved(real wanted)

	function want(level) {
		moved(Math.max(0, Math.min(1, level)));
	}

	implicitWidth: Theme.u(200)
	implicitHeight: Theme.u(22)
	opacity: enabled ? 1 : 0.5
	activeFocusOnTab: interactive && enabled

	Keys.onLeftPressed: want(value - step)
	Keys.onRightPressed: want(value + step)

	Rectangle {
		id: track

		anchors.verticalCenter: parent.verticalCenter
		width: parent.width
		height: Theme.u(6)
		radius: Theme.round(height)
		color: Qt.alpha(Theme.colors.text, 0.16)

		Rectangle {
			width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, slider.value)))
			height: parent.height
			radius: parent.radius
			color: Theme.colors.accent
		}
	}

	Rectangle {
		x: (slider.width - width) * Math.max(0, Math.min(1, slider.value))
		anchors.verticalCenter: parent.verticalCenter
		width: Theme.u(16)
		height: width
		radius: Theme.round(height)
		visible: slider.interactive
		color: Theme.colors.accent
	}

	MouseArea {
		property int wheel: 0

		anchors.fill: parent
		enabled: slider.interactive && slider.enabled
		cursorShape: Qt.PointingHandCursor
		onPressed: event => slider.want(event.x / width)
		onPositionChanged: event => {
			if (pressed)
				slider.want(event.x / width);
		}
		onWheel: event => {
			wheel += event.angleDelta.y;
			const steps = Math.trunc(wheel / 120);
			if (steps !== 0) {
				wheel -= steps * 120;
				slider.want(slider.value + steps * slider.step);
			}
		}
	}

	FocusRing {
		anchors.fill: parent
		visible: slider.activeFocus
		cornerRadius: Theme.round(height)
	}
}
