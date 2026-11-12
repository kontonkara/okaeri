import QtQuick
import qs
import qs.ui

// A tile of the control center: `icon`, `title` and `summary`, filled while
// `checked`. A click says toggled(wanted), or clicked() for one that isn't a
// switch; with `opens`, a page by that name, its arrow opens it. The wheel on it
// says scrolled(steps) with `takesWheel`. A right click on it, or the Menu key,
// opens the page of what else it can do and how it sits among the others, and
// dragged onto another tile it takes that one's place. It shows while `wanted`, unless the
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
	// Small, as Settings.control.size has them: a line, with no summary under it.
	readonly property bool small: Settings.control.size === "small"

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

	implicitHeight: Theme.u(small ? 44 : 58)
	radius: Math.max(0, Theme.cardRadius - Theme.u(2))
	color: checked ? Theme.colors.accent : Qt.alpha(Theme.colors.text, 0.08)
	opacity: switches && !canSwitch ? 0.5 : 1
	visible: wanted && !Settings.control.hidden.includes(name)
	activeFocusOnTab: true

	Behavior on color {
		enabled: Theme.animate

		ColorAnimation {
			duration: Theme.ms(120)
		}
	}

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
			tile.press();
			event.accepted = true;
		} else if (event.key === Qt.Key_Menu) {
			Control.keyed = true;
			Control.showOptions(tile.name);
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

		// Where the button went down, and whether the pointer went far enough from
		// there since to be dragging the tile: over another, it takes that one's place.
		property point from
		property bool dragging: false

		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
		onPressed: event => {
			dragging = false;
			from = Qt.point(event.x, event.y);
		}
		onPositionChanged: event => {
			if (!(pressedButtons & Qt.LeftButton))
				return;
			if (!dragging && Math.hypot(event.x - from.x, event.y - from.y) < Theme.u(10))
				return;
			dragging = true;
			// The tiles' Flow, past the Loader each is in.
			const flow = tile.parent?.parent;
			if (!flow)
				return;
			const at = mapToItem(flow, event.x, event.y);
			const over = flow.childAt(at.x, at.y);
			if (over?.modelData && over.modelData !== tile.name)
				Control.moveTileTo(tile.name, over.modelData);
		}
		onReleased: letGo.restart()
		onCanceled: dragging = false
		onClicked: event => {
			if (dragging)
				return;
			if (event.button === Qt.RightButton)
				Control.showOptions(tile.name);
			else
				tile.press();
		}

		// The click that ends a drag comes after the release.
		Timer {
			id: letGo

			interval: 0
			onTriggered: main.dragging = false
		}
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
			visible: text !== "" && !tile.small
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
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			cursorShape: Qt.PointingHandCursor
			onClicked: event => {
				if (event.button === Qt.RightButton)
					Control.showOptions(tile.name);
				else
					Control.unfolded = tile.opens;
			}
		}
	}

	FocusRing {
		anchors.fill: parent
		visible: tile.activeFocus
		cornerRadius: tile.radius
	}
}
