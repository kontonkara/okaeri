import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// The toasts: on the screen in focus, at Settings.notifications.position, under
// the bar when that's up there and the screen has one, the newest nearest the edge, and beside a panel that
// opens in that corner. They take no keys, and outside them the pointer goes through.
// The window is a strip as wide as they are: a compositor
// blurs all of a surface that asks for it, however little of it shows.
PanelWindow {
	id: window

	// What's on screen, with those on their way out.
	property var cards: []
	readonly property bool wanted: NotificationStore.toasts.length > 0 || cards.length > 0
	readonly property string place: Settings.notifications.position
	readonly property bool atBottom: place.startsWith("bottom")
	readonly property bool atLeft: place.endsWith("left")
	readonly property bool inMiddle: place === "top"
	// The side a toast comes in from and goes out to: in the middle it grows
	// where it is instead.
	readonly property int side: inMiddle ? 0 : atLeft ? -1 : 1
	// How far they go for what's open in their corner.
	readonly property real aside: {
		const widths = Panels.open.filter(panel => panel.align === window.place && panel.screen === window.screen).map(panel => panel.panelWidth);
		return widths.length ? Math.round(Math.max(...widths) + Theme.u(8)) : 0;
	}

	// The same, on its way there.
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
		left: atLeft || inMiddle
		right: !atLeft && !inMiddle
		bottom: true
	}
	// A narrow screen keeps them on it.
	readonly property real offset: Math.max(0, Math.min(Math.round(shift), (screen?.width ?? Infinity) - implicitWidth - Theme.edge))
	margins.left: inMiddle ? Math.round(((screen?.width ?? 0) - implicitWidth) / 2) : atLeft ? offset : 0
	margins.right: atLeft || inMiddle ? 0 : offset
	implicitWidth: list.width + (inMiddle ? 0 : Theme.edge)
	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: Settings.notifications.overFullscreen ? WlrLayer.Overlay : WlrLayer.Top
	WlrLayershell.namespace: "okaeri-toasts"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	BackgroundEffect.blurRegion: Theme.toastBlur ? glass : null
	mask: Region {
		regions: shapes.instances
	}

	Region {
		id: glass

		regions: panes.instances
	}

	Variants {
		id: shapes

		model: window.cards

		Region {
			required property var modelData

			x: list.x + modelData.x
			y: list.y + modelData.y - list.contentY
			width: modelData.width
			height: modelData.height
		}
	}

	// A pixel in from the edges: their corners come in steps, and stay under the
	// card's smooth ones.
	Variants {
		id: panes

		model: window.cards

		Region {
			required property var modelData

			x: list.x + modelData.x + 1
			y: list.y + modelData.y - list.contentY + 1
			width: modelData.width - 2
			height: modelData.height - 2
			radius: Theme.cardRadius
		}
	}

	ListView {
		id: list

		x: window.atLeft ? Theme.edge : 0
		y: window.atBottom ? 0 : Settings.top(window.screen)
		width: Math.round(Theme.u(380))
		height: parent.height - y - (window.atBottom ? Theme.edge : 0)
		verticalLayoutDirection: window.atBottom ? ListView.BottomToTop : ListView.TopToBottom
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
				from: Theme.u(24) * window.side
				to: 0
				duration: 160
				easing.type: Easing.OutCubic
			}

			NumberAnimation {
				property: "scale"
				from: window.side === 0 ? 0.95 : 1
				to: 1
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
				to: Theme.u(24) * window.side
				duration: 160
				easing.type: Easing.OutCubic
			}

			NumberAnimation {
				property: "scale"
				to: window.side === 0 ? 0.95 : 1
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

			NumberAnimation {
				property: "scale"
				to: 1
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
				color: Theme.toastFill
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
