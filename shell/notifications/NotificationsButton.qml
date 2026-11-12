import QtQuick
import qs
import qs.ui

// The bell on the bar, with how many are unread unless Settings.notifications.bellCount
// is off. A click opens the history, a right click turns Do Not Disturb on or off,
// and the wheel gives that half an hour more or less.
BarButton {
	readonly property bool wanted: Settings.notifications.bellAlways || NotificationStore.unread > 0 || NotificationStore.dnd

	icon: NotificationStore.dnd ? "bellOff" : "bell"
	text: Settings.notifications.bellCount && NotificationStore.unread > 0 ? `${NotificationStore.unread}` : ""
	tip: [NotificationStore.unread > 0 ? `${NotificationStore.unread} unread` : "Notifications", NotificationStore.dnd ? (NotificationStore.dndLabel ? `Do Not Disturb · ${NotificationStore.dndLabel}` : "Do Not Disturb") : ""].filter(part => part !== "").join(", ")
	ink: NotificationStore.dnd ? Theme.colors.subtext : Theme.colors.text
	onClicked: NotificationStore.togglePanel()
	onRightClicked: NotificationStore.setDnd(!NotificationStore.dnd, 0)
	takesWheel: true
	onScrolled: steps => NotificationStore.stepDnd(steps)
}
