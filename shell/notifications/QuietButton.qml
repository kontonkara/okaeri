import QtQuick
import qs
import qs.ui

// For an app's toasts to wait a while, beside its name in the history, where
// they all still come: a click keeps `app` quiet for an hour, and another lets it
// speak again. Critical ones show all the same.
Button {
	id: button

	required property string app
	// How long that's still for, in words, if it is.
	readonly property string span: NotificationStore.quietLabel(app)

	height: Theme.u(24)
	flat: true
	activeFocusOnTab: false
	icon: "bellOff"
	iconSize: Theme.u(14)
	ink: span ? Theme.colors.accent : Theme.colors.subtext
	tip: span ? `No toasts from it for ${span}` : "No toasts from it for an hour"
	onClicked: NotificationStore.toggleQuiet(app)
}
