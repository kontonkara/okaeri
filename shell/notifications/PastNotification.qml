import QtQuick

// A notification from before the shell started, as far as a card can tell: what
// sent it is gone, so its actions are too, and closing it is all that's left.
QtObject {
	id: past

	property int id: 0
	property string appName
	property string desktopEntry
	property string summary
	property string body
	property string image
	property string appIcon
	property int urgency: 1
	property bool unread: false

	readonly property bool isPast: true
	readonly property var actions: []
	readonly property var hints: ({})
	readonly property bool lastGeneration: true
	readonly property int expireTimeout: -1

	signal closed

	function dismiss() {
		NotificationStore.forget(past);
	}

	function expire() {
		dismiss();
	}
}
