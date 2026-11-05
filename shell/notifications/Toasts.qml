import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// The toasts: top right on the screen in focus, under the bar, the newest on
// top, and beside a panel that opens there. They take no keys, and outside them
// the pointer goes through.
PanelWindow {
	id: window

	// What's on screen, with those on their way out.
	property var cards: []
	readonly property bool wanted: NotificationStore.toasts.length > 0 || cards.length > 0
	// How far left they go for what's open in their corner.
	readonly property real aside: {
		const widths = Panels.open.filter(panel => panel.align === "top-right" && panel.screen === window.screen).map(panel => panel.panelWidth);
		return widths.length ? Math.round(Math.max(...widths) + Theme.u(8)) : 0;
	}

	// The same, on its way there. Not the list's x: that follows the window's width
	// too, and at a first show it would slide in from the far side.
	property real shift: aside

	Behavior on shift {
		enabled: Theme.animate

		NumberAnimation {
			duration: 160
			easing.type: Easing.OutCubic
		}
	}

	onWantedChanged: {
		if (wanted)
			screen = Niri.focusedScreen;
		visible = wanted;
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
	WlrLayershell.namespace: "okaeri-toasts"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	mask: Region {
		regions: shapes.instances
	}

	Variants {
		id: shapes

		model: window.cards

		Region {
			required property var modelData

			// Not `item`, which wouldn't see the list move aside.
			x: list.x + modelData.x
			y: list.y + modelData.y - list.contentY
			width: modelData.width
			height: modelData.height
		}
	}

	ListView {
		id: list

		x: Math.max(Theme.edge, parent.width - width - Theme.edge - window.shift)
		y: Theme.below
		width: Math.round(Theme.u(380))
		height: parent.height - y
		interactive: false
		spacing: Math.round(Theme.u(8))
		model: ScriptModel {
			values: NotificationStore.toasts
		}


		add: Transition {
			enabled: Theme.animate

			NumberAnimation {
				property: "opacity"
				from: 0
				to: 1
				duration: 160
				easing.type: Easing.OutCubic
			}

			NumberAnimation {
				property: "x"
				from: Theme.u(24)
				to: 0
				duration: 160
				easing.type: Easing.OutCubic
			}
		}

		remove: Transition {
			enabled: Theme.animate

			NumberAnimation {
				property: "opacity"
				to: 0
				duration: 160
				easing.type: Easing.OutCubic
			}

			NumberAnimation {
				property: "x"
				to: Theme.u(24)
				duration: 160
				easing.type: Easing.OutCubic
			}
		}

		displaced: Transition {
			enabled: Theme.animate

			NumberAnimation {
				property: "y"
				duration: 160
				easing.type: Easing.OutCubic
			}

			// It can cut short an add.
			NumberAnimation {
				property: "opacity"
				to: 1
				duration: 160
			}

			NumberAnimation {
				property: "x"
				to: 0
				duration: 160
			}
		}

		delegate: Item {
			id: toast

			required property var modelData

			// A replaced one starts over. The hints are all that's new when a new
			// process sends the same words.
			readonly property var sent: [modelData.summary, modelData.body, modelData.hints]

			onSentChanged: {
				if (life.running)
					life.restart();
			}

			width: ListView.view.width
			height: card.height

			Component.onCompleted: window.cards = window.cards.concat([toast])
			Component.onDestruction: window.cards = window.cards.filter(c => c !== toast)

			NotificationCard {
				id: card

				width: parent.width
				notification: toast.modelData
				closable: false
				color: Theme.colors.background
			}

			// It waits while the pointer is on it.
			HoverHandler {
				id: hover
			}

			Timer {
				id: life

				interval: NotificationStore.lifetime(toast.modelData)
				running: interval > 0 && !hover.hovered
				onTriggered: NotificationStore.takeDown(n => n === toast.modelData)
			}
		}
	}
}
