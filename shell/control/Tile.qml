import QtQuick
import qs
import qs.ui

// A tile of the control center: `icon`, `title` and `summary`, filled while
// `checked`. A click says toggled(wanted), or clicked() for one that isn't a
// switch; with `opens`, a page by that name, its arrow opens it. The wheel on it
// says scrolled(steps) with `takesWheel`. It shows while `wanted`, unless the
// settings leave it out by its `name`.
Rectangle {
	id: tile

	required property string name
	property bool wanted: true
	property string icon
	property string title
	property string summary
	property bool checked: false
	property bool switches: true
	property bool canSwitch: true
	property string opens
	property bool takesWheel: false
	readonly property color ink: checked ? Theme.colors.background : Theme.colors.text

	signal toggled(bool wanted)
	signal clicked
	// Notches of the wheel, with `takesWheel`.
	signal scrolled(int steps)

	function press() {
		if (switches) {
			if (canSwitch)
				toggled(!checked);
		} else {
			clicked();
		}
	}

	implicitHeight: Theme.u(58)
	radius: Math.max(0, Theme.cardRadius - Theme.u(2))
	color: checked ? Theme.colors.accent : Qt.alpha(Theme.colors.text, 0.08)
	opacity: switches && !canSwitch ? 0.5 : 1
	visible: wanted && !Settings.control.hidden.includes(name)
	activeFocusOnTab: true

	Behavior on color {
		enabled: Theme.animate

		ColorAnimation {
			duration: 120
		}
	}

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
			tile.press();
			event.accepted = true;
		} else if (event.key === Qt.Key_Right && tile.opens !== "") {
			Control.keyed = true;
			Control.unfolded = tile.opens;
			event.accepted = true;
		}
	}

	// Under the pointer, and pressed.
	Rectangle {
		anchors.fill: parent
		radius: parent.radius
		color: main.pressed ? Qt.alpha(tile.ink, 0.16) : main.containsMouse ? Qt.alpha(tile.ink, 0.08) : "transparent"
	}

	MouseArea {
		id: main

		property int wheel: 0

		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: tile.press()
		onWheel: event => {
			if (!tile.takesWheel) {
				event.accepted = false;
				return;
			}
			wheel += event.angleDelta.y;
			const steps = Math.trunc(wheel / 120);
			if (steps !== 0) {
				wheel -= steps * 120;
				tile.scrolled(steps);
			}
		}
	}

	Icon {
		id: glyph

		x: Theme.u(14)
		anchors.verticalCenter: parent.verticalCenter
		name: tile.icon
		color: tile.ink
	}

	Column {
		anchors.left: glyph.right
		anchors.leftMargin: Theme.u(12)
		anchors.right: arrow.visible ? arrow.left : parent.right
		anchors.rightMargin: Theme.u(arrow.visible ? 2 : 12)
		anchors.verticalCenter: parent.verticalCenter

		Text {
			width: parent.width
			text: tile.title
			color: tile.ink
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
			font.weight: Theme.fontWeight
		}

		// It can be a name, which anyone nearby picks.
		Text {
			width: parent.width
			visible: text !== ""
			text: tile.summary
			textFormat: Text.PlainText
			maximumLineCount: 1
			color: Qt.alpha(tile.ink, 0.75)
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	// The way to its page: a part of the tile of its own.
	Item {
		id: arrow

		anchors.right: parent.right
		anchors.top: parent.top
		anchors.bottom: parent.bottom
		width: Theme.u(38)
		visible: tile.opens !== ""

		Rectangle {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			width: 1
			height: parent.height - Theme.u(20)
			color: Qt.alpha(tile.ink, 0.2)
		}

		Rectangle {
			anchors.fill: parent
			anchors.margins: Theme.u(4)
			radius: Math.max(0, tile.radius - Theme.u(4))
			color: opening.pressed ? Qt.alpha(tile.ink, 0.16) : opening.containsMouse ? Qt.alpha(tile.ink, 0.1) : "transparent"
		}

		Icon {
			anchors.centerIn: parent
			name: "chevron"
			size: Theme.u(16)
			color: tile.ink
		}

		MouseArea {
			id: opening

			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: Control.unfolded = tile.opens
		}
	}

	FocusRing {
		anchors.fill: parent
		visible: tile.activeFocus
		cornerRadius: tile.radius
	}
}
