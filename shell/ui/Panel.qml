import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// A panel over everything, on the screen in focus, at `align`: "top-right",
// "top-left", "top" (under the bar) or "center". What's put in it goes on a
// card `panelWidth` wide, as tall as it needs. show(), hide() and toggle();
// Escape and a click elsewhere close it. It takes the keyboard while open:
// give what should have the keys `focus: true`.
PanelWindow {
	id: panel

	property string align: "top-right"
	property real panelWidth: Theme.u(380)
	property real padding: Theme.u(12)
	property bool shown: false
	default property alias content: body.data

	signal panelOpened
	signal panelClosed

	function show() {
		screen = Niri.focusedScreen;
		shown = true;
		visible = true;
		panelOpened();
	}

	function hide() {
		if (shown) {
			shown = false;
			panelClosed();
		}
	}

	function toggle() {
		if (shown)
			hide();
		else
			show();
	}

	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}
	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "okaeri-panel"
	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.AllButtons
		onClicked: panel.hide()
	}

	FocusScope {
		id: scope

		readonly property real edge: Theme.u(10)
		readonly property real below: Theme.barHeight + Theme.u(8)

		x: panel.align === "top-right" ? parent.width - width - edge
			: panel.align === "top-left" ? edge : (parent.width - width) / 2
		y: panel.align === "center" ? (parent.height - height) / 2 : below
		width: panel.panelWidth
		height: card.height
		focus: true
		opacity: panel.shown ? 1 : 0
		transform: Translate {
			y: panel.shown ? 0 : -Theme.u(8)

			Behavior on y {
				enabled: Theme.animate

				NumberAnimation {
					duration: 160
					easing.type: Easing.OutCubic
				}
			}
		}

		Keys.onEscapePressed: panel.hide()

		Behavior on opacity {
			enabled: Theme.animate

			NumberAnimation {
				duration: 160
				easing.type: Easing.OutCubic
			}
		}

		onOpacityChanged: {
			if (opacity === 0)
				panel.visible = false;
		}

		Rectangle {
			id: card

			width: parent.width
			height: body.implicitHeight + panel.padding * 2
			radius: Theme.cardRadius
			color: Theme.colors.background
			border.width: 1
			border.color: Theme.border

			// A click on the card isn't a click elsewhere.
			MouseArea {
				anchors.fill: parent
				acceptedButtons: Qt.AllButtons
			}

			Column {
				id: body

				x: panel.padding
				y: panel.padding
				width: parent.width - panel.padding * 2
				spacing: Theme.u(10)
			}
		}
	}
}
