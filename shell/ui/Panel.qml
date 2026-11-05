import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// A panel over everything, on the screen in focus, at `align`: "top-right",
// "top-left", "top" (under the bar) or "center". What's put in it goes on a
// card `panelWidth` wide, as tall as it needs. show(), hide() and toggle();
// Escape, a click elsewhere and another panel opening in the same place close
// it, unless it's `modal`, which is for whoever owns it to close. It takes the
// keyboard while open: give what should have the keys `focus: true`.
PanelWindow {
	id: panel

	property string align: "top-right"
	// For "top" and "center": where across the screen the card has its middle.
	property real middle: width / 2
	property real panelWidth: Theme.u(380)
	property real padding: Theme.u(12)
	property bool modal: false
	property bool shown: false
	// How tall what's put in it can get: the screen, without the bar and the
	// card's own edges.
	readonly property real room: height - Theme.below - Theme.edge - padding * 2
	default property alias content: body.data

	signal panelOpened
	signal panelClosed

	// On screen `on`, if not the one in focus.
	function show(on) {
		screen = on ?? Niri.focusedScreen;
		shown = true;
		visible = true;
		Panels.opened(panel);
		panelOpened();
	}

	function hide() {
		if (shown) {
			shown = false;
			// A fade that never got to start won't say it ended.
			if (scope.opacity === 0)
				visible = false;
			panelClosed();
		}
	}

	function toggle() {
		if (shown)
			hide();
		else
			show();
	}

	function dismiss() {
		if (!modal)
			hide();
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

	Connections {
		target: Panels

		function onOpened(other) {
			if (other !== panel && other.align === panel.align)
				panel.dismiss();
		}
	}

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.AllButtons
		onClicked: panel.dismiss()
	}

	FocusScope {
		id: scope

		// In whole pixels, or its edges would smear.
		x: panel.align === "top-right" ? parent.width - width - Theme.edge
			: panel.align === "top-left" ? Theme.edge
			: Math.round(Math.max(Theme.edge, Math.min(panel.middle - width / 2, parent.width - width - Theme.edge)))
		y: panel.align === "center" ? Math.round((parent.height - height) / 2) : Theme.below
		width: Math.round(panel.panelWidth)
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

		Keys.onEscapePressed: panel.dismiss()

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

			// What's on it starts on a whole pixel too.
			readonly property int inset: Math.round(panel.padding)

			width: parent.width
			height: Math.ceil(body.implicitHeight) + inset * 2
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

				x: card.inset
				y: card.inset
				width: parent.width - card.inset * 2
				spacing: Math.round(Theme.u(10))
			}
		}
	}
}
