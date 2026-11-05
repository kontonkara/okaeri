import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The toasts: top right on the screen in focus, under the bar, the newest on
// top. They take no keys, and outside them the pointer goes through.
PanelWindow {
	id: window

	// What's on screen, with those on their way out.
	property var cards: []
	readonly property bool wanted: NotificationStore.toasts.length > 0 || cards.length > 0

	onWantedChanged: {
		if (wanted)
			screen = Niri.focusedScreen;
		visible = wanted;
	}

	anchors {
		top: true
		right: true
		bottom: true
	}
	implicitWidth: list.width + Theme.edge
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

			item: modelData
		}
	}

	ListView {
		id: list

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
