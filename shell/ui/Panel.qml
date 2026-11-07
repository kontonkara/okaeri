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
//
// It's two surfaces: this one, over the whole screen, is only there for a click
// elsewhere to land on, and the card has a strip of its own, as wide as it and as
// tall as the screen. The compositor blurs all of a surface that asks for it,
// however little of it shows, and a strip of a fixed height isn't resized with
// every step of a card that grows.
PanelWindow {
	id: panel

	property string align: "top-right"
	// For "top" and "center": where across the screen the card has its middle.
	property real middle: across / 2
	property real panelWidth: Theme.u(380)
	property real padding: Theme.u(12)
	property bool modal: false
	property bool shown: false
	// How tall what's put in it can get: the screen, without the bar and the
	// card's own edges.
	readonly property real room: height - Settings.top(screen) - Theme.edge - padding * 2
	// The screen's width: the window's own isn't known yet as it first opens.
	readonly property real across: screen ? screen.width : width
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
	WlrLayershell.namespace: "okaeri-catcher"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	// All but the strip: which of the two is on top isn't up to us.
	mask: Region {
		x: strip.margins.left
		width: strip.width
		height: panel.height
		intersection: Intersection.Xor
	}

	onShownChanged: Panels.open = shown ? Panels.open.concat([panel]) : Panels.open.filter(other => other !== panel)

	// What the card covers now. With `item` it would stay as the first frame had
	// it: a change of scale doesn't reach a region. It's a pixel in from the edge,
	// where its corners, which come in steps, stay under the card's smooth ones.
	Region {
		id: glass

		x: Math.round(scope.originX * (1 - scope.scale)) + 1
		y: Math.round(scope.y + scope.originY * (1 - scope.scale)) + 1
		width: Math.round(scope.width * scope.scale) - 2
		height: Math.round(scope.height * scope.scale) - 2
		radius: card.radius
	}

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

	PanelWindow {
		id: strip

		screen: panel.screen
		visible: panel.visible
		anchors {
			top: true
			left: true
			bottom: true
		}
		// In whole pixels, or its edges would smear.
		margins.left: panel.align === "top-right" ? panel.across - implicitWidth - Theme.edge
			: panel.align === "top-left" ? Theme.edge
			: Math.round(Math.max(Theme.edge, Math.min(panel.middle - implicitWidth / 2, panel.across - implicitWidth - Theme.edge)))
		implicitWidth: Math.round(panel.panelWidth)
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "okaeri-panel"
		WlrLayershell.keyboardFocus: panel.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
		BackgroundEffect.blurRegion: Theme.blur ? glass : null

		// Above and below the card it's still elsewhere.
		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.AllButtons
			onClicked: panel.dismiss()
		}

		FocusScope {
			id: scope

			// Where in it transformOrigin is.
			readonly property real originX: panel.align === "top-right" ? width : panel.align === "top-left" ? 0 : width / 2
			readonly property real originY: panel.align === "center" ? height / 2 : 0

			y: panel.align === "center" ? Math.round((parent.height - height) / 2) : Settings.top(panel.screen)
			width: parent.width
			height: card.height
			focus: true
			opacity: 0
			scale: 0.94
			// It grows out of where it belongs.
			transformOrigin: panel.align === "top-right" ? Item.TopRight
				: panel.align === "top-left" ? Item.TopLeft
				: panel.align === "top" ? Item.Top
				: Item.Center

			Keys.onEscapePressed: panel.dismiss()

			states: State {
				name: "shown"
				when: panel.shown

				PropertyChanges {
					scope.opacity: 1
					scope.scale: 1
				}
			}

			transitions: [
				Transition {
					to: "shown"
					enabled: Theme.animate

					NumberAnimation {
						property: "opacity"
						duration: 140
						easing.type: Easing.OutCubic
					}

					NumberAnimation {
						property: "scale"
						duration: 240
						easing.type: Easing.OutQuint
					}
				},
				Transition {
					from: "shown"
					enabled: Theme.animate

					NumberAnimation {
						properties: "opacity,scale"
						duration: 130
						easing.type: Easing.InCubic
					}
				}
			]

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
				color: Theme.panel

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

				// Over the fill: a border of its own would have the fill stop short of it,
				// and with a fill to see through, it would show as a light line.
				Rectangle {
					anchors.fill: parent
					radius: parent.radius
					color: "transparent"
					border.width: 1
					border.color: Theme.border
				}
			}
		}
	}
}
