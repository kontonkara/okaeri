import QtQuick
import Quickshell
import qs
import qs.ui

// What came in and wasn't closed, with a way to close it all, and Do Not
// Disturb.
Panel {
	id: history

	// It opens on the newest, and nothing has the keys at first: no ring until
	// Tab takes it somewhere.
	onPanelOpened: {
		NotificationStore.opened = [];
		list.positionViewAtBeginning();
		header.forceActiveFocus();
	}

	Item {
		id: header

		width: parent.width
		height: Math.round(clear.height)
		Keys.forwardTo: [list]

		Text {
			anchors.left: parent.left
			anchors.leftMargin: Theme.u(4)
			anchors.verticalCenter: parent.verticalCenter
			text: "Notifications"
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
			font.weight: Theme.fontWeight
		}

		Button {
			id: clear

			anchors.right: parent.right
			height: Theme.u(28)
			visible: list.count > 0
			flat: true
			icon: "trash"
			text: "Clear all"
			onClicked: NotificationStore.clear()

			Keys.onTabPressed: list.enter(0, 1)
		}
	}

	ListView {
		id: list

		// A step of the keys, down for 1. A flick moves on by itself, and that's
		// an animation.
		function scroll(by) {
			if (Theme.animate)
				flick(0, -by * Theme.u(1000));
			else
				contentY = Math.max(originY, Math.min(contentY + by * Theme.u(200), originY + contentHeight - height));
		}

		// The keys onto card `index`, showing it: its first stop, or for -1 its
		// last. Past the ends is what's above and below the list.
		function enter(index, by) {
			if (index < 0) {
				clear.forceActiveFocus();
			} else if (index >= count) {
				toggle.forceActiveFocus();
			} else {
				positionViewAtIndex(index, ListView.Contain);
				const stops = itemAtIndex(index).stops();
				stops[by > 0 ? 0 : stops.length - 1].forceActiveFocus();
			}
		}

		// Tab on card `index`, `by` 1 or -1: on to the next stop or card.
		function tab(index, by) {
			const stops = itemAtIndex(index).stops();
			const next = stops[stops.findIndex(stop => stop.activeFocus) + by];
			if (next)
				next.forceActiveFocus();
			else
				enter(index + by, by);
		}

		width: parent.width
		visible: count > 0
		clip: true
		spacing: Math.round(Theme.u(8))
		boundsBehavior: Flickable.StopAtBounds
		keyNavigationEnabled: false
		// A current card would get the keys when the list does.
		currentIndex: -1
		model: ScriptModel {
			values: NotificationStore.shown
		}

		// With one app it would only say what the cards do.
		section.property: NotificationStore.apps.length > 1 ? "modelData.appName" : ""
		section.delegate: Item {
			id: heading

			required property string section
			readonly property int many: NotificationStore.countOf(section)

			width: ListView.view.width
			height: Theme.u(30)

			MouseArea {
				anchors.fill: parent
				enabled: heading.many > 1
				cursorShape: Qt.PointingHandCursor
				onClicked: NotificationStore.toggleApp(heading.section)
			}

			Row {
				anchors.left: parent.left
				anchors.leftMargin: Theme.u(4)
				anchors.right: closeApp.left
				anchors.verticalCenter: parent.verticalCenter
				spacing: Theme.u(4)

				Text {
					anchors.verticalCenter: parent.verticalCenter
					width: Math.min(implicitWidth, parent.width - Theme.u(20))
					text: (heading.section || "Unknown") + (heading.many > 1 ? ` · ${heading.many}` : "")
					textFormat: Text.PlainText
					color: Theme.colors.subtext
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(2)
				}

				Icon {
					anchors.verticalCenter: parent.verticalCenter
					visible: heading.many > 1
					name: "chevron"
					size: Theme.u(12)
					color: Theme.colors.subtext
					rotation: NotificationStore.opened.includes(heading.section) ? 90 : 0
				}
			}

			Button {
				id: closeApp

				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				height: Theme.u(24)
				flat: true
				activeFocusOnTab: false
				icon: "close"
				iconSize: Theme.u(14)
				onClicked: NotificationStore.clearApp(heading.section)
			}
		}

		Keys.onUpPressed: scroll(-1)
		Keys.onDownPressed: scroll(1)

		// A moment later: its height lays it out again, and that changes
		// contentHeight.
		Binding on height {
			value: Math.min(list.contentHeight, history.height - Theme.u(200))
			delayed: true
		}

		remove: Transition {
			enabled: Theme.animate

			NumberAnimation {
				property: "opacity"
				to: 0
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
		}

		delegate: NotificationCard {
			required property var modelData
			required property int index

			width: ListView.view.width
			notification: modelData
			showsApp: NotificationStore.apps.length < 2
			// They go on with the one that takes its place.
			onKeysLost: Qt.callLater(list.enter, index, 1)

			Keys.onTabPressed: list.tab(index, 1)
			Keys.onBacktabPressed: list.tab(index, -1)
		}
	}

	Column {
		width: parent.width
		visible: list.count === 0
		topPadding: Theme.u(24)
		bottomPadding: Theme.u(24)
		spacing: Theme.u(8)

		Icon {
			anchors.horizontalCenter: parent.horizontalCenter
			name: "bell"
			size: Theme.u(24)
			color: Theme.colors.dim
		}

		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			text: "No notifications"
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}
	}

	Item {
		width: parent.width
		height: Math.max(label.implicitHeight, toggle.implicitHeight) + Theme.u(4)

		Text {
			id: label

			anchors.left: parent.left
			anchors.leftMargin: Theme.u(4)
			anchors.verticalCenter: parent.verticalCenter
			text: "Do Not Disturb"
			color: Theme.colors.text
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

		Toggle {
			id: toggle

			anchors.right: parent.right
			anchors.rightMargin: Theme.u(4)
			anchors.verticalCenter: parent.verticalCenter
			checked: NotificationStore.dnd
			onToggled: wanted => NotificationStore.dnd = wanted

			Keys.onBacktabPressed: list.enter(list.count - 1, -1)
		}
	}
}
