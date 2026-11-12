import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// A panel over everything, on the screen in focus, at `align`: "top-right",
// "top-left", "top" (by the bar, wherever Settings.bar.position has it: under the
// screen's top, over its bottom, or beside one of its sides, where the first is
// at the bar's top, the second by `middle` and the third at its bottom) or
// "center". With `edge` and `off` it's by something else than the bar. What's
// put in it goes on a card `panelWidth` wide, as tall as it needs. show(),
// hide() and toggle(); Escape, a click elsewhere and another panel opening in the
// same place close it, unless it's `modal`, which is for whoever owns it to
// close. A click on the bar isn't one elsewhere: it's the bar's, so that another
// panel is one click away, not two. It takes the keyboard while open: give what
// should have the keys `focus: true`.
//
// It's two surfaces: this one, over the whole screen, is only there for a click
// elsewhere to land on, and the card has a strip of its own, as wide as it and as
// tall as the screen. The compositor blurs all of a surface that asks for it,
// however little of it shows, and a strip of a fixed height isn't resized with
// every step of a card that grows.
PanelWindow {
	id: panel

	property string align: "top-right"
	// For "top": where along the bar the card has its middle, across the screen
	// or, by a bar at a side, down it.
	property real middle: upright ? (screen ? screen.height : height) / 2 : across / 2
	// The edge of the screen it stands by, and how far off that: the bar's, unless
	// it's a panel of something else there.
	property string edge: Settings.barAt
	property real off: Settings.inset(screen, edge)
	readonly property bool upright: edge === "left" || edge === "right"
	property real panelWidth: Theme.u(380)
	property real padding: Theme.u(12)
	property bool modal: false
	// What Escape does before it closes the panel: true if that was all of it.
	property var escapes: () => false
	property bool shown: false
	// How tall what's put in it can get: the screen, without the bar and the
	// card's own edges.
	readonly property real room: height - (edge === "top" ? off : Settings.top(screen)) - (edge === "bottom" ? off : Settings.bottom(screen)) - padding * 2
	// By a bar at the bottom it stands on that, and grows up out of it.
	readonly property bool low: edge === "bottom" && align !== "center"
	// By one at a side it stands beside that.
	readonly property bool beside: upright && align !== "center"
	// Where on the screen that puts it, for what else is there.
	readonly property string place: beside ? `${align === "top-left" ? "top" : align === "top-right" ? "bottom" : "middle"}-${edge}`
		: low ? align.replace("top", "bottom") : align
	// The screen's width: the window's own isn't known yet as it first opens.
	readonly property real across: screen ? screen.width : width
	// How deep the bar's band of the screen is, the clicks in which are the bar's:
	// none with no bar here, and a modal panel keeps them all.
	readonly property real band: !modal && Settings.barOn(screen) ? Theme.edge + Theme.barHeight : 0
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

	function leave() {
		if (!escapes())
			dismiss();
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
	// All but the strip, as which of the two is on top isn't up to us, and but the
	// bar's band.
	mask: Region {
		x: strip.margins.left
		width: strip.width
		height: panel.height
		intersection: Intersection.Xor

		Region {
			x: Settings.barAt === "right" ? panel.width - panel.band : 0
			y: Settings.barAt === "bottom" ? panel.height - panel.band : 0
			width: Settings.barSide ? panel.band : panel.width
			height: Settings.barSide ? panel.height : panel.band
		}
	}

	onShownChanged: Panels.open = shown ? Panels.open.concat([panel]) : Panels.open.filter(other => other !== panel)

	// What the card covers now. With `item` it would stay as the first frame had
	// it: a change of scale doesn't reach a region. It's a pixel in from the edge,
	// where its corners, which come in steps, stay under the card's smooth ones.
	Region {
		id: glass

		x: Math.round(scope.shiftX + scope.originX * (1 - scope.scale)) + 1
		y: Math.round(scope.y + scope.shiftY + scope.originY * (1 - scope.scale)) + 1
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

		function onAway() {
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
		margins.left: panel.beside ? (panel.edge === "left" ? Math.round(panel.off) : Math.round(panel.across - implicitWidth - panel.off))
			: panel.align === "top-right" ? panel.across - implicitWidth - Theme.edge
			: panel.align === "top-left" ? Theme.edge
			: Math.round(Math.max(Theme.edge, Math.min(panel.middle - implicitWidth / 2, panel.across - implicitWidth - Theme.edge)))
		implicitWidth: Math.round(panel.panelWidth)
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "okaeri-panel"
		WlrLayershell.keyboardFocus: panel.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
		BackgroundEffect.blurRegion: Theme.blur ? glass : null
		// All of it but the bar's band.
		mask: Region {
			width: strip.width
			height: strip.height

			Region {
				x: Settings.barAt === "right" ? panel.across - panel.band - strip.margins.left : -strip.margins.left
				y: Settings.barAt === "bottom" ? strip.height - panel.band : 0
				width: Settings.barSide ? panel.band : panel.across
				height: Settings.barSide ? strip.height : panel.band
				intersection: Intersection.Subtract
			}
		}

		// Above and below the card it's still elsewhere.
		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.AllButtons
			onClicked: panel.dismiss()
		}

		FocusScope {
			id: scope

			// Where in it transformOrigin is.
			readonly property real originX: panel.beside ? (panel.edge === "left" ? 0 : width) : panel.align === "top-right" ? width : panel.align === "top-left" ? 0 : width / 2
			readonly property real originY: panel.align === "center" ? height / 2
				: panel.beside ? (panel.align === "top-left" ? 0 : panel.align === "top-right" ? height : height / 2)
				: panel.low ? height : 0

			y: panel.align === "center" ? Math.round((parent.height - height) / 2)
				: panel.beside ? (panel.align === "top-left" ? Theme.edge
					: panel.align === "top-right" ? parent.height - Theme.edge - height
					: Math.round(Math.max(Theme.edge, Math.min(panel.middle - height / 2, parent.height - Theme.edge - height))))
				: panel.low ? Math.round(parent.height - panel.off - height)
				: panel.edge === "top" ? Math.round(panel.off) : Settings.top(panel.screen)
			width: parent.width
			height: card.height
			focus: true
			opacity: 0
			scale: Theme.panelMotion === "grow" ? 0.94 : 1
			// How far it is from its place, 1 out of sight and 0 there: it slides that
			// far in from the bar, or with no bar beside it from below, with
			// Theme.panelMotion "slide".
			property real away: 1
			readonly property real lift: Theme.panelMotion === "slide" ? Theme.u(28) : 0
			readonly property real shiftX: panel.beside ? away * lift * (panel.edge === "left" ? -1 : 1) : 0
			readonly property real shiftY: panel.beside ? 0 : away * lift * (panel.align === "center" || panel.low ? 1 : -1)

			transform: Translate {
				x: scope.shiftX
				y: scope.shiftY
			}
			// It grows out of where it belongs.
			transformOrigin: panel.align === "center" ? Item.Center
				: panel.beside ? [[Item.TopLeft, Item.Left, Item.BottomLeft], [Item.TopRight, Item.Right, Item.BottomRight]][panel.edge === "left" ? 0 : 1][panel.align === "top-left" ? 0 : panel.align === "top-right" ? 2 : 1]
				: panel.align === "top-right" ? (panel.low ? Item.BottomRight : Item.TopRight)
				: panel.align === "top-left" ? (panel.low ? Item.BottomLeft : Item.TopLeft)
				: panel.low ? Item.Bottom : Item.Top

			Keys.onEscapePressed: panel.leave()

			states: State {
				name: "shown"
				when: panel.shown

				PropertyChanges {
					scope.opacity: 1
					scope.scale: 1
					scope.away: 0
				}
			}

			transitions: [
				Transition {
					to: "shown"
					enabled: Theme.animate

					NumberAnimation {
						property: "opacity"
						duration: Theme.ms(140)
						easing.type: Easing.OutCubic
					}

					NumberAnimation {
						properties: "scale,away"
						duration: Theme.ms(240)
						easing.type: Easing.OutQuint
					}
				},
				Transition {
					from: "shown"
					enabled: Theme.animate

					NumberAnimation {
						properties: "opacity,scale,away"
						duration: Theme.ms(130)
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
