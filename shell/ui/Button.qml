import QtQuick
import qs

// A button: `text`, `icon` (one of Theme.icons), both, or what's put in it,
// after those; without text it's square. `filled` for the main action, `flat`
// for one that shows only under the pointer. Tab gets to it; Enter and Space
// press it.
Rectangle {
	id: button

	property string text
	property string icon
	property bool filled: false
	property bool flat: false
	// Beside what's on it, with text.
	property real pad: Theme.u(14)
	property real iconSize: Theme.u(18)
	// As wide as its text gets, past which it's cut, 0 for as wide as it is.
	property real longest: 0
	// What's cut off slides into view under the pointer.
	property bool scrolls: false
	// What's on it starts at its left, for one in a list, not in its middle.
	property bool atStart: false
	// With this the wheel on it says scrolled(steps), and goes no further.
	property bool takesWheel: false
	// What Tip says of it.
	property string tip
	property color ink: filled ? Theme.colors.background : Theme.colors.text
	default property alias content: row.data

	signal clicked
	signal rightClicked
	signal middleClicked
	// Notches of the wheel, up is positive.
	signal scrolled(int steps)

	implicitWidth: text ? row.implicitWidth + pad * 2 : height
	implicitHeight: Theme.u(34)
	radius: Theme.round(height)
	color: filled ? Theme.colors.accent : flat ? "transparent" : Qt.alpha(Theme.colors.text, 0.1)
	opacity: enabled ? 1 : 0.5
	activeFocusOnTab: enabled

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
			button.clicked();
			event.accepted = true;
		}
	}

	Rectangle {
		anchors.fill: parent
		radius: parent.radius
		color: pointer.pressed ? Qt.alpha(button.ink, 0.16) : pointer.containsMouse ? Qt.alpha(button.ink, 0.08) : "transparent"

		Behavior on color {
			enabled: Theme.animate

			ColorAnimation {
				duration: 120
			}
		}
	}

	Row {
		id: row

		anchors.centerIn: button.atStart ? undefined : parent
		anchors.left: button.atStart ? parent.left : undefined
		anchors.leftMargin: button.pad
		anchors.verticalCenter: button.atStart ? parent.verticalCenter : undefined
		spacing: Theme.u(6)

		Icon {
			anchors.verticalCenter: parent.verticalCenter
			visible: button.icon !== ""
			name: button.icon
			size: button.iconSize
			color: button.ink
		}

		Item {
			id: label

			// How much of it is cut off, and whether that slides into view now.
			readonly property real over: words.implicitWidth - width
			readonly property bool sliding: button.scrolls && over > 0 && pointer.containsMouse && Theme.animate

			anchors.verticalCenter: parent.verticalCenter
			visible: button.text !== ""
			width: button.longest > 0 ? Math.min(words.implicitWidth, button.longest) : words.implicitWidth
			height: words.implicitHeight
			clip: true

			Text {
				id: words

				width: label.sliding ? implicitWidth : label.width
				text: button.text
				textFormat: Text.PlainText
				elide: label.sliding ? Text.ElideNone : Text.ElideRight
				color: button.ink
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
				font.weight: Theme.fontWeight
				font.features: {
					"tnum": 1
				}
			}

			// Along to its end at a reading pace, a rest, and back.
			SequentialAnimation {
				running: label.sliding
				loops: Animation.Infinite
				onRunningChanged: {
					if (!running)
						words.x = 0;
				}

				PauseAnimation {
					duration: 600
				}

				NumberAnimation {
					target: words
					property: "x"
					to: -label.over
					duration: Math.max(0, label.over * 25)
					easing.type: Easing.InOutSine
				}

				PauseAnimation {
					duration: 1200
				}

				NumberAnimation {
					target: words
					property: "x"
					to: 0
					duration: 300
					easing.type: Easing.OutCubic
				}
			}
		}
	}

	MouseArea {
		id: pointer

		property int wheel: 0

		anchors.fill: parent
		enabled: button.enabled
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		cursorShape: Qt.PointingHandCursor
		onClicked: event => {
			if (event.button === Qt.RightButton)
				button.rightClicked();
			else if (event.button === Qt.MiddleButton)
				button.middleClicked();
			else
				button.clicked();
		}
		onWheel: event => {
			if (!button.takesWheel) {
				event.accepted = false;
				return;
			}
			// A touchpad comes in small parts of a notch.
			wheel += event.angleDelta.y;
			const steps = Math.trunc(wheel / 120);
			if (steps !== 0) {
				wheel -= steps * 120;
				button.scrolled(steps);
			}
		}
	}

	FocusRing {
		anchors.fill: parent
		visible: button.activeFocus
		cornerRadius: button.radius
	}

	// Only where there's one: a list's rows are buttons too.
	Loader {
		anchors.fill: parent
		active: button.tip !== ""

		sourceComponent: Tip {
			text: button.tip
			listens: false
			hovered: pointer.containsMouse
			pressed: pointer.pressed
		}
	}
}
