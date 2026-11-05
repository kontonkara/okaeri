import QtQuick
import qs
import qs.ui

// The bell on the bar, with how many are unread. A click opens the history.
Button {
	anchors.verticalCenter: parent.verticalCenter
	height: Theme.u(28)
	flat: true
	iconSize: Theme.barIcon
	pad: Theme.u(6)
	activeFocusOnTab: false
	icon: NotificationStore.dnd ? "bellOff" : "bell"
	text: NotificationStore.unread > 0 ? `${NotificationStore.unread}` : ""
	ink: NotificationStore.dnd ? Theme.colors.subtext : Theme.colors.text
	onClicked: NotificationStore.togglePanel()
}
